<script setup>
import { computed, nextTick, ref, useTemplateRef } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

// The field stores exactly the markdown that is typed. A WYSIWYG editor would have to parse the
// text into a document and write it back out on every edit, and that round trip rewrites content
// it cannot model verbatim - single newlines come back as hard breaks, for one - which would
// silently edit flows that are already live. Authors get formatting controls and a preview of the
// visitor's view instead, and the stored value is never touched by anything but their own typing.
const props = defineProps({
  modelValue: { type: String, default: '' },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  rows: { type: Number, default: 6 },
});

const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

const textarea = useTemplateRef('textarea');
const isPreviewing = ref(false);

// Rendered through the same formatter the live-chat widget uses, so the preview is the visitor's
// view rather than an approximation of it.
const preview = computed(() => formatMessage(props.modelValue, false, false));

const value = computed(() => props.modelValue ?? '');

// Every control works on the current selection and puts the caret back where the author expects
// it, so the toolbar and typing stay interchangeable.
const applyToSelection = mutate => {
  const element = textarea.value;
  const start = element?.selectionStart ?? value.value.length;
  const end = element?.selectionEnd ?? value.value.length;

  const result = mutate({
    before: value.value.slice(0, start),
    selected: value.value.slice(start, end),
    after: value.value.slice(end),
  });

  emit('update:modelValue', result.text);
  nextTick(() => {
    element?.focus();
    element?.setSelectionRange(result.selectionStart, result.selectionEnd);
  });
};

const wrap = (prefix, suffix, placeholderKey) =>
  applyToSelection(({ before, selected, after }) => {
    const body = selected || t(placeholderKey);
    return {
      text: `${before}${prefix}${body}${suffix}${after}`,
      selectionStart: before.length + prefix.length,
      selectionEnd: before.length + prefix.length + body.length,
    };
  });

const insertLink = () =>
  applyToSelection(({ before, selected, after }) => {
    const label = selected || t('FLOWS.EDITOR.INSPECTOR.MARKDOWN.LINK_TEXT');
    const url = t('FLOWS.EDITOR.INSPECTOR.MARKDOWN.LINK_URL');
    return {
      text: `${before}[${label}](${url})${after}`,
      // Land on the URL, since that is the part the author still has to fill in.
      selectionStart: before.length + label.length + 3,
      selectionEnd: before.length + label.length + 3 + url.length,
    };
  });

// List, quote and heading markers belong to whole lines, so the selection is grown out to the
// line boundaries before the marker is applied.
const prefixLines = marker =>
  applyToSelection(({ before, selected, after }) => {
    const lineStart = before.lastIndexOf('\n') + 1;
    const leading = before.slice(0, lineStart);
    const block = before.slice(lineStart) + selected;
    const lines = block.split('\n');
    const marked = lines
      .map((line, index) =>
        marker === '1. ' ? `${index + 1}. ${line}` : `${marker}${line}`
      )
      .join('\n');

    return {
      text: `${leading}${marked}${after}`,
      selectionStart: leading.length,
      selectionEnd: leading.length + marked.length,
    };
  });

const CONTROLS = [
  {
    key: 'BOLD',
    icon: 'i-lucide-bold',
    run: () => wrap('**', '**', 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.BOLD_TEXT'),
  },
  {
    key: 'ITALIC',
    icon: 'i-lucide-italic',
    run: () => wrap('*', '*', 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.ITALIC_TEXT'),
  },
  {
    key: 'STRIKE',
    icon: 'i-lucide-strikethrough',
    run: () => wrap('~~', '~~', 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.STRIKE_TEXT'),
  },
  {
    key: 'CODE',
    icon: 'i-lucide-code',
    run: () => wrap('`', '`', 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.CODE_TEXT'),
  },
  { key: 'LINK', icon: 'i-lucide-link', run: insertLink },
  {
    key: 'BULLET_LIST',
    icon: 'i-lucide-list',
    run: () => prefixLines('- '),
  },
  {
    key: 'NUMBERED_LIST',
    icon: 'i-lucide-list-ordered',
    run: () => prefixLines('1. '),
  },
  { key: 'QUOTE', icon: 'i-lucide-quote', run: () => prefixLines('> ') },
  { key: 'HEADING', icon: 'i-lucide-heading', run: () => prefixLines('## ') },
];
</script>

<template>
  <div class="flex flex-col gap-1 min-w-0">
    <label v-if="label" class="mb-0.5 text-sm font-medium text-n-slate-12">
      {{ label }}
    </label>

    <div
      class="flex flex-col rounded-lg border border-solid border-n-weak bg-n-alpha-black2 focus-within:border-n-brand"
    >
      <div
        class="flex flex-wrap items-center gap-0.5 border-b border-solid border-n-weak px-1.5 py-1"
      >
        <button
          v-for="control in CONTROLS"
          :key="control.key"
          type="button"
          :title="t(`FLOWS.EDITOR.INSPECTOR.MARKDOWN.${control.key}`)"
          :aria-label="t(`FLOWS.EDITOR.INSPECTOR.MARKDOWN.${control.key}`)"
          :disabled="isPreviewing"
          class="flex items-center justify-center rounded p-1 text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12 disabled:opacity-40"
          @click="control.run"
        >
          <span :class="control.icon" class="size-4" />
        </button>

        <button
          type="button"
          :title="
            t(
              isPreviewing
                ? 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.EDIT'
                : 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.PREVIEW'
            )
          "
          class="ms-auto flex items-center gap-1 rounded px-1.5 py-1 text-xs text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
          @click="isPreviewing = !isPreviewing"
        >
          <span
            :class="isPreviewing ? 'i-lucide-pencil' : 'i-lucide-eye'"
            class="size-3.5"
          />
          {{
            t(
              isPreviewing
                ? 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.EDIT'
                : 'FLOWS.EDITOR.INSPECTOR.MARKDOWN.PREVIEW'
            )
          }}
        </button>
      </div>

      <div
        v-if="isPreviewing"
        v-dompurify-html="preview"
        class="prose prose-sm min-h-24 max-w-none break-words px-3 py-2 text-sm text-n-slate-12 prose-p:my-1 prose-headings:mb-1 prose-headings:mt-2 prose-a:text-n-blue-11 prose-ul:my-1 prose-ol:my-1 prose-li:my-0.5"
      />
      <textarea
        v-else
        ref="textarea"
        :value="value"
        :rows="rows"
        :placeholder="placeholder"
        class="w-full resize-y border-0 bg-transparent px-3 py-2 text-sm text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-0"
        @input="emit('update:modelValue', $event.target.value)"
      />
    </div>
  </div>
</template>
