<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ConditionRows from './ConditionRows.vue';
import MarkdownField from './MarkdownField.vue';
import {
  BUTTON_TYPES,
  CONVERSATION_STATUSES,
  DEFAULT_TIMEOUT_MINUTES,
  DELAY_RANGE,
  MAX_BUTTONS,
  waitsForVisitor,
} from '../constants';

const props = defineProps({
  node: { type: Object, required: true },
  nodeId: { type: String, required: true },
  isStart: { type: Boolean, default: false },
  teams: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
});

const emit = defineEmits(['delete', 'makeStart', 'updateNode']);

const { t } = useI18n();

const params = computed(() => props.node.params);
const canTimeout = computed(() => waitsForVisitor(props.node));
const route = useRoute();
const fileInput = ref(null);
const isUploading = ref(false);
const uploadError = ref('');

// Uploading beats asking someone to find a public URL for an image they already have. The file
// goes through the account's configured storage, so wherever attachments live, these live too.
const onPickImage = async event => {
  const file = event.target.files?.[0];
  event.target.value = '';
  if (!file) return;

  uploadError.value = '';
  isUploading.value = true;
  try {
    const { fileUrl } = await uploadFile(file, route.params.accountId);
    params.value.image_url = fileUrl;
  } catch (error) {
    uploadError.value =
      error?.response?.data?.error ||
      t('FLOWS.EDITOR.INSPECTOR.IMAGE_UPLOAD_FAILED');
  } finally {
    isUploading.value = false;
  }
};
const isMessage = computed(() =>
  ['send_message', 'quick_replies'].includes(props.node.type)
);

const buttonTypeOptions = computed(() =>
  BUTTON_TYPES.map(value => ({
    value,
    label: t(`FLOWS.BUTTON_TYPES.${value.toUpperCase()}`),
  }))
);

const statusOptions = computed(() =>
  CONVERSATION_STATUSES.map(value => ({
    value,
    label: t(`FLOWS.STATUSES.${value.toUpperCase()}`),
  }))
);

const teamOptions = computed(() =>
  props.teams.map(team => ({ value: team.id, label: team.name }))
);

const agentOptions = computed(() =>
  props.agents.map(agent => ({ value: agent.id, label: agent.name }))
);

const contentTypeOptions = computed(() => [
  { value: 'text', label: t('FLOWS.EDITOR.INSPECTOR.INPUT_FREE_TEXT') },
  { value: 'input_email', label: t('FLOWS.EDITOR.INSPECTOR.INPUT_EMAIL') },
]);

const labelsText = computed({
  get: () => (params.value.labels ?? []).join(', '),
  set: value => {
    params.value.labels = value
      .split(',')
      .map(label => label.trim())
      .filter(Boolean);
  },
});

const addButton = () => {
  if (!params.value.buttons) params.value.buttons = [];
  params.value.buttons.push({ title: '', type: 'reply', value: '' });
};

// Dropping a reply button also drops the edge that hung off it, so the graph cannot keep a
// target no handle can reach.
const removeButton = index => {
  params.value.buttons.splice(index, 1);
};

// Clearing the timeout must drop its edge too, or the graph keeps a target no handle can reach.
// The node itself belongs to the editor's definition, so the change is asked for rather than
// written through the prop.
const toggleTimeout = () => {
  emit(
    'updateNode',
    props.node.timeout_minutes
      ? { timeout_minutes: undefined, timeout_next: undefined }
      : { timeout_minutes: DEFAULT_TIMEOUT_MINUTES }
  );
};

const timeoutMinutes = computed({
  get: () => props.node.timeout_minutes,
  set: value => emit('updateNode', { timeout_minutes: value }),
});
</script>

<template>
  <aside
    class="flex w-80 shrink-0 flex-col gap-4 overflow-y-auto border-s border-n-weak bg-n-solid-1 p-4"
  >
    <div class="flex items-center justify-between gap-2">
      <h3 class="text-sm font-medium text-n-slate-12">
        {{ t(`FLOWS.NODE_TYPES.${node.type.toUpperCase()}`) }}
      </h3>
      <span class="text-xs text-n-slate-10 font-mono">{{ nodeId }}</span>
    </div>

    <template v-if="isMessage || node.type === 'collect_input'">
      <MarkdownField
        v-model="params.content"
        :label="t('FLOWS.EDITOR.INSPECTOR.CONTENT')"
        :placeholder="t('FLOWS.EDITOR.INSPECTOR.CONTENT_PLACEHOLDER')"
      />
      <p class="-mt-2 text-xs text-n-slate-10">
        {{ t('FLOWS.EDITOR.INSPECTOR.VARIABLE_HINT') }}
      </p>
    </template>

    <template v-if="isMessage">
      <div class="flex flex-col gap-2">
        <Input
          v-model="params.image_url"
          :label="t('FLOWS.EDITOR.INSPECTOR.IMAGE_URL')"
          placeholder="https://…"
        />
        <div class="flex items-center gap-2">
          <Button
            :label="
              isUploading
                ? t('FLOWS.EDITOR.INSPECTOR.IMAGE_UPLOADING')
                : t('FLOWS.EDITOR.INSPECTOR.IMAGE_UPLOAD')
            "
            icon="i-lucide-upload"
            size="sm"
            variant="faded"
            :disabled="isUploading"
            @click="fileInput?.click()"
          />
          <Button
            v-if="params.image_url"
            icon="i-lucide-x"
            size="sm"
            variant="faded"
            color="ruby"
            :label="t('FLOWS.EDITOR.INSPECTOR.IMAGE_REMOVE')"
            @click="params.image_url = ''"
          />
        </div>
        <input
          ref="fileInput"
          type="file"
          accept="image/png,image/jpeg,image/gif,image/webp"
          class="hidden"
          @change="onPickImage"
        />
        <img
          v-if="params.image_url"
          :src="params.image_url"
          alt=""
          class="object-contain w-full rounded max-h-32 bg-n-alpha-1"
        />
        <p v-if="uploadError" class="text-xs text-n-ruby-11">
          {{ uploadError }}
        </p>
      </div>

      <div class="flex flex-col gap-2">
        <span class="text-sm text-n-slate-12">
          {{ t('FLOWS.EDITOR.INSPECTOR.BUTTONS') }}
        </span>
        <div
          v-for="(button, index) in params.buttons ?? []"
          :key="index"
          class="flex flex-col gap-2 rounded-lg border border-n-weak p-2"
        >
          <div class="flex items-end gap-2">
            <Input
              v-model="button.title"
              size="sm"
              :placeholder="t('FLOWS.EDITOR.INSPECTOR.BUTTON_TITLE')"
            />
            <Button
              icon="i-lucide-trash-2"
              size="sm"
              color="ruby"
              variant="ghost"
              @click="removeButton(index)"
            />
          </div>
          <Select v-model="button.type" :options="buttonTypeOptions" />
          <Input
            v-if="button.type === 'link'"
            v-model="button.url"
            size="sm"
            placeholder="https://…"
          />
          <Input
            v-else
            v-model="button.value"
            size="sm"
            :placeholder="t('FLOWS.EDITOR.INSPECTOR.BUTTON_VALUE')"
          />
        </div>
        <Button
          :label="t('FLOWS.EDITOR.INSPECTOR.ADD_BUTTON')"
          icon="i-lucide-plus"
          size="sm"
          variant="faded"
          :disabled="(params.buttons ?? []).length >= MAX_BUTTONS"
          @click="addButton"
        />
        <p class="text-xs text-n-slate-10">
          {{ t('FLOWS.EDITOR.INSPECTOR.CHANNEL_LIMIT_HINT') }}
        </p>
      </div>
    </template>

    <template v-if="node.type === 'collect_input'">
      <Input
        v-model="params.variable"
        :label="t('FLOWS.EDITOR.INSPECTOR.VARIABLE')"
        placeholder="email"
      />
      <Select v-model="params.content_type" :options="contentTypeOptions" />
    </template>

    <template v-if="node.type === 'condition'">
      <ConditionRows v-model="params.conditions" />
    </template>

    <template v-if="node.type === 'delay'">
      <Input
        v-model.number="params.minutes"
        type="number"
        :label="t('FLOWS.EDITOR.INSPECTOR.DELAY_MINUTES')"
        :min="String(DELAY_RANGE.min)"
        :max="String(DELAY_RANGE.max)"
      />
    </template>

    <template v-if="node.type === 'add_label'">
      <Input
        v-model="labelsText"
        :label="t('FLOWS.EDITOR.INSPECTOR.LABELS')"
        :placeholder="t('FLOWS.EDITOR.INSPECTOR.LABELS_PLACEHOLDER')"
      />
    </template>

    <template v-if="node.type === 'assign_team'">
      <Select v-model="params.team_id" :options="teamOptions" />
    </template>

    <template v-if="node.type === 'assign_agent'">
      <Select v-model="params.agent_id" :options="agentOptions" />
    </template>

    <template v-if="node.type === 'change_status'">
      <Select v-model="params.status" :options="statusOptions" />
    </template>

    <div
      v-if="canTimeout"
      class="flex flex-col gap-2 border-t border-n-weak pt-4"
    >
      <Button
        :label="
          node.timeout_minutes
            ? t('FLOWS.EDITOR.INSPECTOR.REMOVE_TIMEOUT')
            : t('FLOWS.EDITOR.INSPECTOR.ADD_TIMEOUT')
        "
        icon="i-lucide-timer"
        size="sm"
        variant="faded"
        @click="toggleTimeout"
      />
      <Input
        v-if="node.timeout_minutes"
        v-model.number="timeoutMinutes"
        type="number"
        :label="t('FLOWS.EDITOR.INSPECTOR.TIMEOUT_MINUTES')"
        :min="String(DELAY_RANGE.min)"
        :max="String(DELAY_RANGE.max)"
      />
      <p v-if="node.timeout_minutes" class="text-xs text-n-slate-10">
        {{ t('FLOWS.EDITOR.INSPECTOR.TIMEOUT_HINT') }}
      </p>
    </div>

    <div class="mt-auto flex flex-col gap-2 border-t border-n-weak pt-4">
      <Button
        v-if="!isStart"
        :label="t('FLOWS.EDITOR.INSPECTOR.MAKE_START')"
        icon="i-lucide-play"
        size="sm"
        variant="faded"
        @click="emit('makeStart')"
      />
      <Button
        :label="t('FLOWS.EDITOR.INSPECTOR.DELETE_NODE')"
        icon="i-lucide-trash-2"
        size="sm"
        color="ruby"
        variant="faded"
        :disabled="isStart"
        @click="emit('delete')"
      />
      <p v-if="isStart" class="text-xs text-n-slate-10">
        {{ t('FLOWS.EDITOR.INSPECTOR.START_LOCKED') }}
      </p>
    </div>
  </aside>
</template>
