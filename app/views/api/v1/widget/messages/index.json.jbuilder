json.payload do
  json.array! @messages do |message|
    # A recalled message reaches the contact as a placeholder: the original stays on the record
    # for the team, but is never sent to the person it was taken back from.
    json.id message.id
    json.content message.recalled? ? t('conversations.messages.recalled') : message.content
    json.message_type message.message_type_before_type_cast
    json.content_type message.recalled? ? 'text' : message.content_type
    json.content_attributes message.recalled? ? { recalled: true } : message.content_attributes
    json.created_at message.created_at.to_i
    json.conversation_id message.conversation.display_id
    json.attachments message.attachments.map(&:push_event_data) if message.attachments.present? && !message.recalled?
    json.sender message.sender.push_event_data if message.sender
  end
end
json.meta do
  json.contact_last_seen_at @conversation.contact_last_seen_at.to_i if @conversation.present?
end
