<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import { useMapGetter } from 'dashboard/composables/store.js';
import CustomButton from 'shared/components/Button.vue';
import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';
import GateModal from '../components/PreChat/GateModal.vue';
import { usePreChatGate } from 'widget/composables/usePreChatGate';

const store = useStore();

const groupedMessages = useMapGetter('conversation/getGroupedConversation');
const widgetColor = useMapGetter('appConfig/getWidgetColor');
const { isPreChatPending } = usePreChatGate();

const textColor = computed(() => getContrastingTextColor(widgetColor.value));

// A modal rather than a route: the conversation the visitor is being asked about stays visible
// behind it, and nothing is torn down if they dismiss it.
const isGateModalOpen = ref(false);

onMounted(() => {
  store.dispatch('conversation/setUserLastSeen');
});
</script>

<template>
  <div class="relative flex flex-col flex-1 overflow-hidden rounded-b-lg">
    <div class="flex flex-1 overflow-auto">
      <ConversationWrap :grouped-messages="groupedMessages" />
    </div>
    <!-- The prompt is the button: one target the whole width of the composer it replaces. -->
    <div v-if="isPreChatPending" class="px-5 pt-1 pb-4">
      <CustomButton
        block
        class="font-medium !rounded-full !py-2.5 !text-[0.8125rem] !leading-5"
        :bg-color="widgetColor"
        :text-color="textColor"
        @click="isGateModalOpen = true"
      >
        {{ $t('PRE_CHAT_FORM.GATE_PROMPT') }}
      </CustomButton>
    </div>
    <ChatFooter v-else class="px-5" />
    <GateModal v-if="isGateModalOpen" @close="isGateModalOpen = false" />
  </div>
</template>
