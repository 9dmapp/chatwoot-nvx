# Freezes a conversation's labels every time it is resolved.
#
# Labels are mutable and live on the conversation, so they only ever describe what it is about
# now. Recording them at each resolution is what lets a reopened conversation be counted again
# under whatever it was about the second time, without losing the visitor's history.
class ConversationResolutionListener < BaseListener
  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]

    ConversationResolution.create!(
      account_id: conversation.account_id,
      conversation_id: conversation.id,
      inbox_id: conversation.inbox_id,
      assignee_id: conversation.assignee_id,
      labels: conversation.label_list.to_a,
      resolved_at: event.timestamp
    )
  end
end
