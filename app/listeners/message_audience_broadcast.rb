# How a message event reaches the team and the contact.
#
# Creation goes out as one broadcast to everyone, as it always has: a message cannot be created
# already recalled, and splitting it would double the broadcast jobs for every message sent.
#
# An update is sent to each audience separately, because a recalled message has to reach the
# contact stripped of the content it was recalled for while the team keeps the original. One
# payload for both would put the original in the browser of the person it was taken back from,
# leaving the recall to depend on what their client chooses to draw.
module MessageAudienceBroadcast
  private

  def broadcast_message_created(event, event_name)
    message, account = extract_message_and_account(event)
    conversation = message.conversation
    tokens = user_tokens(account, conversation.inbox.members) + contact_tokens(conversation.contact_inbox, message)

    broadcast(account, tokens, event_name, message.push_event_data)
  end

  def broadcast_message_updated(event, event_name, extra = {})
    message, account = extract_message_and_account(event)
    conversation = message.conversation

    broadcast(account, user_tokens(account, conversation.inbox.members), event_name, message.push_event_data.merge(extra))
    broadcast(account, contact_tokens(conversation.contact_inbox, message), event_name, message.push_event_data_for_contact.merge(extra))
  end
end
