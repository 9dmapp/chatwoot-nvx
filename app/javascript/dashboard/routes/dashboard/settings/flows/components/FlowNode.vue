<script setup>
import { computed } from 'vue';
import { Handle, Position } from '@vue-flow/core';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { NODE_ICONS, outgoingEdges } from '../constants';

const props = defineProps({
  data: { type: Object, required: true },
  selected: { type: Boolean, default: false },
});

const { t } = useI18n();

const node = computed(() => props.data.node);
const handles = computed(() => outgoingEdges(node.value));
const icon = computed(() => NODE_ICONS[node.value.type] ?? 'i-lucide-circle');

// One line of the node's own configuration, so the graph is readable without opening each node.
const summary = computed(() => {
  const params = node.value.params ?? {};
  switch (node.value.type) {
    case 'send_message':
    case 'quick_replies':
    case 'collect_input':
      return params.content || params.image_url;
    case 'delay':
      return t('FLOWS.EDITOR.NODE.DELAY_SUMMARY', { minutes: params.minutes });
    case 'add_label':
      return (params.labels ?? []).join(', ');
    case 'change_status':
      return params.status;
    case 'condition':
      return t('FLOWS.EDITOR.NODE.CONDITION_SUMMARY', {
        count: (params.conditions ?? []).length,
      });
    default:
      return '';
  }
});
</script>

<template>
  <div
    class="w-64 rounded-xl border bg-n-solid-1 shadow-sm transition-colors"
    :class="
      selected
        ? 'border-n-brand ring-1 ring-n-brand'
        : 'border-n-weak hover:border-n-slate-6'
    "
  >
    <Handle
      type="target"
      :position="Position.Top"
      class="!w-2.5 !h-2.5 !bg-n-slate-8 !border-n-solid-1"
    />

    <div class="flex items-start gap-2 px-3 pt-3">
      <Icon :icon="icon" class="size-4 shrink-0 mt-0.5 text-n-slate-11" />
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-n-slate-12 truncate">
          {{ t(`FLOWS.NODE_TYPES.${node.type.toUpperCase()}`) }}
        </p>
        <p v-if="summary" class="text-xs text-n-slate-11 line-clamp-2">
          {{ summary }}
        </p>
      </div>
      <span
        v-if="data.isStart"
        class="shrink-0 rounded px-1.5 py-0.5 text-[0.625rem] font-medium bg-n-brand/10 text-n-brand"
      >
        {{ t('FLOWS.EDITOR.NODE.START') }}
      </span>
    </div>

    <div v-if="handles.length" class="mt-2 border-t border-n-weak">
      <div
        v-for="edge in handles"
        :key="edge.handle"
        class="flex items-center justify-between gap-2 px-3 py-1.5"
      >
        <span class="text-xs text-n-slate-11 truncate">{{ edge.label }}</span>
        <Handle
          :id="edge.handle"
          type="source"
          :position="Position.Right"
          class="!relative !top-auto !right-auto !inset-auto !transform-none !w-2.5 !h-2.5 !bg-n-slate-9 !border-n-solid-1"
        />
      </div>
    </div>
    <div v-else class="h-2" />
  </div>
</template>
