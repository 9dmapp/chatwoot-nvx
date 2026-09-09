# Routes conversation and message events into the flow engine. Exclusivity is decided here, at
# the single point every entry and resume passes through.
class FlowListener < BaseListener
  def conversation_created(event)
    conversation = event.data[:conversation]
    return unless enabled?(conversation.account)
    return if active_session(conversation).present?

    Flows::TriggerService.new(conversation: conversation).perform
  end

  def message_created(event)
    message = event.data[:message]
    return unless enabled?(message.account)
    return unless message.incoming? && !message.private?

    session = active_session(message.conversation)
    return Flows::TriggerService.new(conversation: message.conversation, message: message).perform if session.blank?
    # The visitor's opening message races conversation creation, so anything at or before the
    # message that asked the question is not an answer to it.
    return if session.awaiting_message_id.blank? || message.id <= session.awaiting_message_id

    Flows::ResumeService.new(session: session, message: message, reply: message.content).perform
  end

  # The web widget answers in place rather than sending an incoming message: buttons write
  # submitted_values onto the bot's own message, the email prompt writes submitted_email. Every
  # other channel replies with a normal incoming message.
  def message_updated(event)
    message = event.data[:message]
    return unless enabled?(message.account)

    session = active_session(message.conversation)
    return if session.blank? || session.awaiting_message_id != message.id

    reply = submitted_value(message)
    return if reply.blank?

    Flows::ResumeService.new(session: session, message: message, reply: reply).perform
  end

  # The widget reports this when the visitor opens the chat, before they have typed anything.
  def webwidget_triggered(event)
    contact_inbox = event.data[:contact_inbox]
    return unless enabled?(contact_inbox&.inbox&.account)

    Flows::WidgetTriggerService.new(contact_inbox: contact_inbox, event_info: event.data[:event_info]).perform
  end

  private

  def submitted_value(message)
    case message.content_type
    when 'input_select' then message.content_attributes['submitted_values']&.first&.dig('value')
    when 'input_email' then message.content_attributes['submitted_email']
    end
  end

  def enabled?(account)
    account.present? && account.feature_enabled?('flows')
  end

  def active_session(conversation)
    FlowSession.active.find_by(conversation_id: conversation.id)
  end
end
