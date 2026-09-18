# Records a row every time a conversation is resolved, carrying the session labels the agent
# picked while doing it.
#
# Every resolve passes through here - agent, API integration, automation, auto-resolve - so the
# table is a complete record of sessions, and the ones closed without a label are visible as such
# rather than missing. The labels travel on the event because this listener runs asynchronously,
# by which time the request that held the agent's choice is long gone.
class ConversationResolutionListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]

    ConversationResolution.create!(
      account_id: conversation.account_id,
      conversation_id: conversation.id,
      inbox_id: conversation.inbox_id,
      assignee_id: conversation.assignee_id,
      session_label_ids: Array(event.data[:session_label_ids]),
      resolved_at: event.timestamp
    )
  end
end
