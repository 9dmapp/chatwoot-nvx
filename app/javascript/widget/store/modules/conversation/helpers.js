import { MESSAGE_TYPE } from 'widget/helpers/constants';
import { isASubmittedFormMessage } from 'shared/helpers/MessageTypeHelper';

import getUuid from '../../../helpers/uuid';
export const createTemporaryMessage = ({ attachments, content, replyTo }) => {
  const timestamp = new Date().getTime() / 1000;
  return {
    id: getUuid(),
    content,
    attachments,
    status: 'in_progress',
    replyTo,
    created_at: timestamp,
    message_type: MESSAGE_TYPE.INCOMING,
  };
};

const getSenderName = message => (message.sender ? message.sender.name : '');

const startsNewGroup = (message, previousMessage) => {
  if (!previousMessage) return true;

  return (
    getSenderName(message) !== getSenderName(previousMessage) ||
    message.message_type !== previousMessage.message_type ||
    isASubmittedFormMessage(previousMessage)
  );
};

// The avatar and sender name mark the *start* of a run of messages from one sender, so a flow
// that sends four bubbles at once introduces itself before the visitor reads them rather than
// after.
export const groupConversationBySender = conversationsForADate =>
  conversationsForADate.map((message, index) => {
    const showAvatar =
      !isASubmittedFormMessage(message) &&
      startsNewGroup(message, conversationsForADate[index - 1]);
    return { showAvatar, ...message };
  });

export const findUndeliveredMessage = (messageInbox, { content }) =>
  Object.values(messageInbox).filter(
    message => message.content === content && message.status === 'in_progress'
  );

export const getNonDeletedMessages = ({ messages }) => {
  return messages.filter(
    item => !(item.content_attributes && item.content_attributes.deleted)
  );
};
