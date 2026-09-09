# Admits a visitor into a flow the moment they open the chat, before they have said anything.
# There is no conversation at that point, so one is created the way proactive campaigns do.
class Flows::WidgetTriggerService
  TRIGGER_TYPE = 'webwidget_triggered'.freeze
  # Context the widget reports on open, worth keeping on the conversation the visitor lands in.
  CONVERSATION_CONTEXT_KEYS = %w[referer browser widget_language browser_language initiated_at].freeze

  def initialize(contact_inbox:, event_info: {})
    @contact_inbox = contact_inbox
    @event_info = (event_info || {}).with_indifferent_access
    @account = contact_inbox.inbox.account
  end

  def perform
    # Resolved before anything is created: opening the bubble must not leave an empty conversation
    # behind on an inbox where no flow wants this visitor.
    flow = eligible_flow
    return if flow.blank?

    conversation = conversation_for(flow)
    return if conversation.blank?

    Flows::TriggerService.new(conversation: conversation, trigger_type: TRIGGER_TYPE).perform
  end

  private

  def listening_flows
    Flow.published.for_inbox(@contact_inbox.inbox_id).where(account_id: @account.id, trigger_type: TRIGGER_TYPE).order(:id)
  end

  def eligible_flow
    listening_flows.detect { |flow| off_cooldown?(flow) }
  end

  # No cooldown means the original behaviour: greet a visitor once and never again. With one set,
  # the visitor is admitted again as soon as that many minutes have passed since the flow last
  # ran for them.
  def off_cooldown?(flow)
    previous = FlowSession.where(flow_id: flow.id, conversation_id: @contact_inbox.conversations.select(:id))
                          .order(:created_at).last
    return true if previous.nil?
    return false if flow.cooldown_minutes.blank?

    previous.created_at <= flow.cooldown_minutes.minutes.ago
  end

  # A returning visitor is re-greeted in the conversation they already have rather than
  # accumulating a new one on every visit.
  def conversation_for(flow)
    @contact_inbox.with_lock do
      existing = @contact_inbox.conversations.order(:id).last
      next existing if existing.present? && flow.cooldown_minutes.present?
      next if existing.present?

      Conversation.create!(
        account_id: @account.id,
        inbox_id: @contact_inbox.inbox_id,
        contact_id: @contact_inbox.contact_id,
        contact_inbox_id: @contact_inbox.id,
        additional_attributes: @event_info.slice(*CONVERSATION_CONTEXT_KEYS)
      )
    end
  end
end
