<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

// Asked once per chat session, as the agent closes it. The answer is recorded against that
// session alone, so a visitor who comes back about something else is categorised afresh and
// nobody has to undo the last visit's answer.
const props = defineProps({
  labels: { type: Array, default: () => [] },
  required: { type: Boolean, default: false },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();

const dialogRef = ref(null);
const selected = ref([]);

const canConfirm = computed(() => !props.required || selected.value.length > 0);

const isSelected = id => selected.value.includes(id);

const toggle = id => {
  selected.value = isSelected(id)
    ? selected.value.filter(labelId => labelId !== id)
    : [...selected.value, id];
};

const open = () => {
  selected.value = [];
  dialogRef.value?.open();
};

const close = () => dialogRef.value?.close();

const onConfirm = () => emit('confirm', [...selected.value]);

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('SESSION_LABELS.DIALOG.TITLE')"
    :description="
      required
        ? t('SESSION_LABELS.DIALOG.DESCRIPTION_REQUIRED')
        : t('SESSION_LABELS.DIALOG.DESCRIPTION')
    "
    :confirm-button-label="t('SESSION_LABELS.DIALOG.CONFIRM')"
    :cancel-button-label="t('SESSION_LABELS.DIALOG.CANCEL')"
    :disable-confirm-button="!canConfirm"
    @confirm="onConfirm"
  >
    <div class="flex flex-wrap gap-2">
      <button
        v-for="label in labels"
        :key="label.id"
        type="button"
        class="rounded-lg border border-solid px-3 py-1.5 text-sm"
        :class="
          isSelected(label.id)
            ? 'border-n-brand bg-n-brand text-white'
            : 'border-n-weak bg-n-solid-1 text-n-slate-12 hover:border-n-slate-6'
        "
        @click="toggle(label.id)"
      >
        {{ label.title }}
      </button>
    </div>

    <p v-if="!labels.length" class="text-sm text-n-slate-11">
      {{ t('SESSION_LABELS.DIALOG.NONE_CONFIGURED') }}
    </p>
  </Dialog>
</template>
