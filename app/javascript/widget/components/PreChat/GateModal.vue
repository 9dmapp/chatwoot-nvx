<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import PreChatForm from 'widget/components/PreChat/Form.vue';
import { markPreChatAnswered } from 'widget/composables/usePreChatGate';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const preChatMessage = computed(
  () => window.chatwootWebChannel?.preChatFormOptions?.pre_chat_message || ''
);

const preChatFormOptions = computed(() => {
  const options = window.chatwootWebChannel?.preChatFormOptions || {};
  return {
    // The message is rendered as the modal's title, so it is withheld from the form itself.
    preChatMessage: '',
    preChatFields: options.pre_chat_fields || [],
  };
});

// The visitor is already in a conversation, so this only identifies them. Creating one here
// would clear the messages sitting behind the modal, which is exactly what the visitor is
// looking at while they fill it in.
const onSubmit = async ({
  fullName,
  emailAddress,
  phoneNumber,
  contactCustomAttributes,
  conversationCustomAttributes,
}) => {
  await store.dispatch('contacts/update', {
    user: {
      email: emailAddress,
      name: fullName,
      phone_number: phoneNumber,
      custom_attributes: contactCustomAttributes,
    },
  });

  if (Object.keys(conversationCustomAttributes || {}).length) {
    await store.dispatch(
      'conversation/setCustomAttributes',
      conversationCustomAttributes
    );
  }

  markPreChatAnswered(store.getters['contacts/getCurrentUser'].id);
  emit('close');
};
</script>

<template>
  <div
    class="fixed inset-0 z-30 flex flex-col items-center justify-center gap-4 px-5 bg-[rgba(0,0,0,0.45)]"
    @click.self="emit('close')"
  >
    <div
      class="w-full max-w-xs overflow-hidden shadow-xl rounded-2xl bg-n-background dark:bg-n-solid-2"
    >
      <p
        class="px-5 pt-5 pb-1 text-base font-semibold text-center text-n-slate-12"
      >
        {{ preChatMessage }}
      </p>
      <PreChatForm
        :options="preChatFormOptions"
        hide-message-field
        hide-field-labels
        form-class="flex flex-col w-full px-5"
        input-extra-class="!bg-n-slate-3 dark:!bg-n-solid-3 !outline-none !py-2.5"
        submit-wrapper-class="mt-4 -mx-5 px-5 pt-4 border-t border-solid border-n-weak [&>button]:!mt-0 [&>button]:!mb-0 [&>button]:!py-3.5"
        :submit-label="t('PRE_CHAT_FORM.GATE_SUBMIT')"
        @submit-pre-chat="onSubmit"
      />
    </div>
    <button
      class="flex items-center justify-center rounded-full size-9 bg-n-alpha-black1 text-n-slate-1 hover:bg-n-alpha-black2"
      :aria-label="t('PRE_CHAT_FORM.GATE_CLOSE')"
      @click="emit('close')"
    >
      <i class="i-lucide-x size-5" />
    </button>
  </div>
</template>
