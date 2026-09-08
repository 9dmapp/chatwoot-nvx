<script>
export default {
  components: {},
  props: {
    action: {
      type: Object,
      default: () => {},
    },
    isSelected: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['optionSelect'],
  methods: {
    onClick() {
      this.$emit('optionSelect', this.action);
    },
  },
};
</script>

<template>
  <li class="list-none">
    <button
      class="w-full px-3 py-2 text-[0.8125rem] leading-5 text-center whitespace-normal border-0 rounded-[0.45rem] cursor-pointer bg-n-slate-3 dark:bg-n-solid-3 text-n-slate-12 hover:bg-n-slate-4"
      :class="{ 'bg-n-slate-4': isSelected }"
      @click="onClick"
    >
      {{ action.title }}
    </button>
  </li>
</template>
