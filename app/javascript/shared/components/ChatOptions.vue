<script>
import ChatOption from 'shared/components/ChatOption.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

export default {
  components: {
    ChatOption,
  },
  props: {
    title: {
      type: String,
      default: '',
    },
    options: {
      type: Array,
      default: () => [],
    },
    selected: {
      type: String,
      default: '',
    },
    hideFields: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['optionSelect'],
  setup() {
    const { formatMessage } = useMessageFormatter();
    return {
      formatMessage,
    };
  },
  methods: {
    isSelected(option) {
      return this.selected === option.id;
    },
    onClick(selectedOption) {
      this.$emit('optionSelect', selectedOption);
    },
  },
};
</script>

<template>
  <div
    class="chat-bubble agent !p-0 w-64 rounded-[0.45rem] overflow-hidden mt-1 bg-n-background dark:bg-n-solid-3"
  >
    <div
      v-dompurify-html="formatMessage(title, false)"
      class="px-4 py-3 text-sm font-normal leading-normal text-n-slate-12"
    />
    <!-- The choices run edge to edge under the prompt, divided rather than boxed, so they read
      as the next step instead of as decorations attached to the text. -->
    <ul
      v-if="!hideFields"
      class="flex flex-col w-full gap-1.5 p-3 border-t border-solid border-n-weak"
    >
      <ChatOption
        v-for="option in options"
        :key="option.id"
        :action="option"
        :is-selected="isSelected(option)"
        @option-select="onClick"
      />
    </ul>
  </div>
</template>
