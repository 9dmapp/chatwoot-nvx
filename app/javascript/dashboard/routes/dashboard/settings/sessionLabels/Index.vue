<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useSessionLabelsStore } from 'dashboard/stores/sessionLabels';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const { t } = useI18n();
const store = useSessionLabelsStore();

const formDialogRef = ref(null);
const archiveDialogRef = ref(null);
const editing = ref(null);
const selected = ref(null);
const draft = ref({ title: '', description: '' });

const records = computed(() => store.records);
const uiFlags = computed(() => store.uiFlags);

const active = computed(() =>
  records.value.filter(label => !label.archived_at)
);
const archived = computed(() =>
  records.value.filter(label => label.archived_at)
);

const openCreate = () => {
  editing.value = null;
  draft.value = { title: '', description: '' };
  formDialogRef.value?.open();
};

const openEdit = label => {
  editing.value = label;
  draft.value = { title: label.title, description: label.description ?? '' };
  formDialogRef.value?.open();
};

const save = async () => {
  try {
    if (editing.value) {
      await store.update({ id: editing.value.id, ...draft.value });
    } else {
      await store.create(draft.value);
    }
    formDialogRef.value?.close();
  } catch (error) {
    useAlert(t('SESSION_LABELS.SAVE_ERROR'));
  }
};

const confirmArchive = label => {
  selected.value = label;
  archiveDialogRef.value?.open();
};

// Archiving keeps the label out of the picker while past sessions, and the insights for them,
// keep their category.
const archive = async () => {
  try {
    await store.delete(selected.value.id);
    await store.get();
    useAlert(t('SESSION_LABELS.ARCHIVE_SUCCESS'));
  } catch (error) {
    useAlert(t('SESSION_LABELS.ARCHIVE_ERROR'));
  }
};

onMounted(() => store.get());
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="t('SESSION_LABELS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SESSION_LABELS.HEADER')"
        :description="t('SESSION_LABELS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="t('SESSION_LABELS.NEW')"
            size="sm"
            @click="openCreate"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <p v-if="!active.length" class="text-sm text-n-slate-11">
        {{ t('SESSION_LABELS.EMPTY') }}
      </p>

      <ul class="flex flex-col gap-2">
        <li
          v-for="label in active"
          :key="label.id"
          class="flex items-center gap-3 rounded-xl border border-solid border-n-weak bg-n-solid-1 px-4 py-3"
        >
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium text-n-slate-12">
              {{ label.title }}
            </p>
            <p v-if="label.description" class="text-xs text-n-slate-11">
              {{ label.description }}
            </p>
          </div>
          <Button
            icon="i-lucide-pencil"
            size="sm"
            variant="ghost"
            @click="openEdit(label)"
          />
          <Button
            icon="i-lucide-archive"
            size="sm"
            variant="ghost"
            color="ruby"
            @click="confirmArchive(label)"
          />
        </li>
      </ul>

      <div v-if="archived.length" class="mt-6 flex flex-col gap-2">
        <p class="text-xs font-medium uppercase text-n-slate-10">
          {{ t('SESSION_LABELS.ARCHIVED') }}
        </p>
        <p class="text-xs text-n-slate-11">
          {{ t('SESSION_LABELS.ARCHIVED_HINT') }}
        </p>
        <ul class="flex flex-wrap gap-2">
          <li
            v-for="label in archived"
            :key="label.id"
            class="rounded-lg border border-solid border-n-weak px-2 py-1 text-xs text-n-slate-11"
          >
            {{ label.title }}
          </li>
        </ul>
      </div>
    </template>

    <Dialog
      ref="formDialogRef"
      :title="
        editing ? t('SESSION_LABELS.EDIT_TITLE') : t('SESSION_LABELS.NEW')
      "
      :confirm-button-label="t('SESSION_LABELS.SAVE')"
      :disable-confirm-button="!draft.title.trim()"
      @confirm="save"
    >
      <div class="flex flex-col gap-4">
        <Input
          v-model="draft.title"
          :label="t('SESSION_LABELS.TITLE')"
          :placeholder="t('SESSION_LABELS.TITLE_PLACEHOLDER')"
          autofocus
        />
        <Input
          v-model="draft.description"
          :label="t('SESSION_LABELS.DESCRIPTION_FIELD')"
        />
      </div>
    </Dialog>

    <Dialog
      ref="archiveDialogRef"
      type="alert"
      :title="t('SESSION_LABELS.ARCHIVE_TITLE')"
      :description="
        t('SESSION_LABELS.ARCHIVE_DESCRIPTION', { name: selected?.title })
      "
      :confirm-button-label="t('SESSION_LABELS.ARCHIVE')"
      @confirm="archive"
    />
  </SettingsLayout>
</template>
