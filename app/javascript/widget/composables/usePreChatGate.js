import { computed, ref } from 'vue';
import { LocalStorage } from 'shared/helpers/localStorage';
import { useMapGetter } from 'dashboard/composables/store.js';

const ANSWERED_KEY = 'chatwoot_prechat_answered';

// Chatwoot gives every anonymous visitor an auto-generated name, so `has_name` is true from the
// first page load and cannot tell us whether a person actually filled the form in. Recording the
// submission is the only honest signal for a form that asks for a name and nothing else.
// Module scope on purpose: the gate and the modal that satisfies it are separate call sites.
const answeredContactId = ref(LocalStorage.get(ANSWERED_KEY));

export function markPreChatAnswered(contactId) {
  LocalStorage.set(ANSWERED_KEY, contactId);
  answeredContactId.value = contactId;
}

/**
 * Whether the visitor still owes the pre-chat form an answer.
 *
 * A conversation can reach the message view before the form has been filled — a flow greeting
 * fired on widget load, or a returning visitor resuming a bot conversation — and the composer
 * would then let them skip the gate entirely.
 *
 * The "answered" test mirrors PreChat/Form.vue's own field filtering. If the two disagreed, the
 * gate could demand a field the form then hides, and the visitor would be stuck in a loop.
 *
 * @returns {{ isPreChatPending: import('vue').ComputedRef<boolean> }}
 */
export function usePreChatGate() {
  const currentUser = useMapGetter('contacts/getCurrentUser');
  const hasVisitorMessages = useMapGetter('conversation/getHasVisitorMessages');

  const preChatFields = computed(() => {
    const channelConfig = window.chatwootWebChannel || {};
    if (!channelConfig.preChatFormEnabled) return [];
    return channelConfig.preChatFormOptions?.pre_chat_fields || [];
  });

  const isAnswered = fieldName => {
    const {
      has_email: hasEmail,
      has_phone_number: hasPhoneNumber,
      identifier,
    } = currentUser.value;

    switch (fieldName) {
      case 'emailAddress':
        return !!hasEmail;
      case 'phoneNumber':
        return !!hasPhoneNumber;
      // The form hides the name once the contact is identified by any means, so the gate has to
      // accept the same or it would demand a field the form no longer offers.
      case 'fullName':
        return !!(identifier || hasEmail || hasPhoneNumber);
      // Custom attributes are extra context, not the contact record the gate exists to collect.
      default:
        return true;
    }
  };

  const isPreChatPending = computed(() => {
    // Until the contact has loaded, every field reads as unanswered; showing the gate on that
    // basis would flash it in front of visitors who have already answered.
    if (!currentUser.value.id) return false;
    if (answeredContactId.value === currentUser.value.id) return false;
    if (hasVisitorMessages.value) return false;

    return preChatFields.value.some(
      field => field.enabled && field.required && !isAnswered(field.name)
    );
  });

  return { isPreChatPending };
}
