<script setup>
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useFlowsStore } from 'dashboard/stores/flows';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import { TRIGGER_TYPES, errorMessage } from './constants';

const router = useRouter();
const { t } = useI18n();
const getters = useStoreGetters();
const store = useStore();
const flowsStore = useFlowsStore();

const createDialogRef = ref(null);
const deleteDialogRef = ref(null);
const selectedFlow = ref(null);
const draft = ref({ name: '', trigger_type: 'conversation_created' });

const records = computed(() => flowsStore.records);
const inboxes = computed(() => getters['inboxes/getInboxes'].value);

const inboxNames = flow =>
  (flow.inbox_ids ?? [])
    .map(id => inboxes.value.find(inbox => inbox.id === id)?.name)
    .filter(Boolean)
    .join(', ');
const uiFlags = computed(() => flowsStore.uiFlags);
const accountId = computed(() => getters.getCurrentAccountId.value);

const triggerOptions = computed(() =>
  TRIGGER_TYPES.map(value => ({
    value,
    label: t(`FLOWS.TRIGGER_TYPES.${value.toUpperCase()}`),
  }))
);

const openEditor = flow =>
  router.push({
    name: 'flows_edit',
    params: { accountId: accountId.value, flowId: flow.id },
  });

const openCreate = () => {
  draft.value = { name: '', trigger_type: 'conversation_created' };
  createDialogRef.value?.open();
};

const createFlow = async () => {
  try {
    const flow = await flowsStore.create({
      ...draft.value,
      draft_definition: {},
    });
    createDialogRef.value?.close();
    openEditor(flow);
  } catch (error) {
    useAlert(errorMessage(error, t('FLOWS.LIST.CREATE_ERROR')));
  }
};

const toggleActive = async flow => {
  try {
    await flowsStore.update({ id: flow.id, active: !flow.active });
  } catch (error) {
    useAlert(errorMessage(error, t('FLOWS.LIST.TOGGLE_ERROR')));
  }
};

const confirmDelete = flow => {
  selectedFlow.value = flow;
  deleteDialogRef.value?.open();
};

const deleteFlow = async () => {
  try {
    await flowsStore.delete(selectedFlow.value.id);
    useAlert(t('FLOWS.LIST.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(errorMessage(error, t('FLOWS.LIST.DELETE_ERROR')));
  }
};

onMounted(() => {
  store.dispatch('inboxes/get');
  flowsStore.get();
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="$t('FLOWS.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('FLOWS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('FLOWS.HEADER')"
        :description="$t('FLOWS.DESCRIPTION')"
      >
        <template #actions>
          <Button :label="$t('FLOWS.LIST.NEW')" size="sm" @click="openCreate" />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <ul class="flex flex-col gap-2">
        <li
          v-for="flow in records"
          :key="flow.id"
          class="flex items-center gap-3 rounded-xl border border-n-weak bg-n-solid-1 px-4 py-3"
        >
          <button class="min-w-0 flex-1 text-start" @click="openEditor(flow)">
            <p class="text-sm font-medium text-n-slate-12 truncate">
              {{ flow.name }}
            </p>
            <p class="text-xs text-n-slate-11">
              {{ $t(`FLOWS.TRIGGER_TYPES.${flow.trigger_type.toUpperCase()}`) }}
              <template v-if="inboxNames(flow)">
                &middot; {{ inboxNames(flow) }}
              </template>
              <template v-if="flow.published_version_number">
                &middot;
                {{
                  $t('FLOWS.LIST.VERSION', {
                    version: flow.published_version_number,
                  })
                }}
              </template>
            </p>
          </button>

          <span
            v-if="!flow.published_version_id"
            class="rounded px-2 py-1 text-xs text-n-amber-12 bg-n-amber-3"
          >
            {{ $t('FLOWS.LIST.DRAFT') }}
          </span>
          <span
            v-else-if="flow.active"
            class="rounded px-2 py-1 text-xs text-n-teal-12 bg-n-teal-3"
          >
            {{ $t('FLOWS.LIST.LIVE') }}
          </span>
          <span
            v-else
            class="rounded px-2 py-1 text-xs text-n-slate-11 bg-n-alpha-2"
          >
            {{ $t('FLOWS.LIST.PAUSED') }}
          </span>

          <Button
            :label="
              flow.active ? $t('FLOWS.LIST.PAUSE') : $t('FLOWS.LIST.ACTIVATE')
            "
            size="sm"
            variant="faded"
            :disabled="!flow.published_version_id"
            @click="toggleActive(flow)"
          />
          <Button
            icon="i-lucide-pencil"
            size="sm"
            variant="ghost"
            @click="openEditor(flow)"
          />
          <Button
            icon="i-lucide-trash-2"
            size="sm"
            variant="ghost"
            color="ruby"
            @click="confirmDelete(flow)"
          />
        </li>
      </ul>
    </template>

    <Dialog
      ref="createDialogRef"
      :title="$t('FLOWS.LIST.NEW')"
      :confirm-button-label="$t('FLOWS.LIST.CREATE')"
      @confirm="createFlow"
    >
      <div class="flex flex-col gap-4">
        <Input v-model="draft.name" :label="$t('FLOWS.LIST.NAME')" autofocus />
        <Select v-model="draft.trigger_type" :options="triggerOptions" />
      </div>
    </Dialog>

    <Dialog
      ref="deleteDialogRef"
      type="alert"
      :title="$t('FLOWS.LIST.DELETE_TITLE')"
      :description="
        $t('FLOWS.LIST.DELETE_DESCRIPTION', { name: selectedFlow?.name })
      "
      :confirm-button-label="$t('FLOWS.LIST.DELETE')"
      @confirm="deleteFlow"
    />
  </SettingsLayout>
</template>
