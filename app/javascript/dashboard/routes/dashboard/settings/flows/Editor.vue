<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import dagre from 'dagre';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';

import { useAlert } from 'dashboard/composables';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useFlowsStore } from 'dashboard/stores/flows';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import FlowNode from './components/FlowNode.vue';
import NodeInspector from './components/NodeInspector.vue';
import ConditionRows from './components/ConditionRows.vue';
import {
  NODE_DEFAULTS,
  NODE_ICONS,
  NODE_TYPES,
  TRIGGER_TYPES,
  edgeTarget,
  errorMessage,
  outgoingEdges,
  setEdgeTarget,
  stableStringify,
} from './constants';

const NODE_WIDTH = 256;
const NODE_HEIGHT = 120;

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();
const flowsStore = useFlowsStore();
const { fitView } = useVueFlow();

const flowId = Number(route.params.flowId);
const flow = ref(null);
const selectedNodeId = ref(null);
const isSaving = ref(false);

// Local working copy: nothing reaches the server until Save, and nothing reaches live
// conversations until Publish.
const definition = reactive({
  start_node_id: null,
  entry_conditions: [],
  nodes: {},
});
const meta = reactive({
  name: '',
  description: '',
  trigger_type: 'conversation_created',
  inbox_ids: [],
  cooldown_minutes: null,
});

const teams = computed(() => getters['teams/getTeams'].value);
const inboxes = computed(() => getters['inboxes/getInboxes'].value);

const inboxOptions = computed(() =>
  inboxes.value.map(inbox => ({ value: inbox.id, label: inbox.name }))
);
const agents = computed(() => getters['agents/getAgents'].value);

const selectedNode = computed(() =>
  selectedNodeId.value ? definition.nodes[selectedNodeId.value] : null
);

// The inspector asks for changes to the node's own fields rather than writing through its prop.
// An undefined value means "remove this key", which is how a timeout and its edge are cleared.
const applyNodeUpdate = changes => {
  const node = selectedNode.value;
  if (!node) return;

  Object.entries(changes).forEach(([key, value]) => {
    if (value === undefined) {
      delete node[key];
    } else {
      node[key] = value;
    }
  });
};

const isDirty = computed(
  () =>
    !!flow.value &&
    stableStringify(flow.value.draft_definition ?? {}) !==
      stableStringify(definition)
);

const hasUnpublishedChanges = computed(
  () =>
    !!flow.value?.published_definition &&
    stableStringify(flow.value.published_definition) !==
      stableStringify(definition)
);

const triggerOptions = computed(() =>
  TRIGGER_TYPES.map(value => ({
    value,
    label: t(`FLOWS.TRIGGER_TYPES.${value.toUpperCase()}`),
  }))
);

const flowNodes = computed(() =>
  Object.entries(definition.nodes).map(([id, node]) => ({
    id,
    type: 'flow',
    position: node.position ?? { x: 0, y: 0 },
    data: { node, isStart: id === definition.start_node_id },
  }))
);

const flowEdges = computed(() =>
  Object.entries(definition.nodes).flatMap(([id, node]) =>
    outgoingEdges(node)
      .map(edge => ({ edge, target: edgeTarget(node, edge.handle) }))
      .filter(({ target }) => target && definition.nodes[target])
      .map(({ edge, target }) => ({
        id: `${id}:${edge.handle}`,
        source: id,
        sourceHandle: edge.handle,
        target,
        label: edge.label,
        animated: edge.handle === 'timeout_next',
      }))
  )
);

const load = async () => {
  // The store helpers resolve to the record itself, not the raw axios response.
  const record = await flowsStore
    .show(flowId)
    .catch(() => flowsStore.getFlow(flowId));
  if (!record) return;

  flow.value = record;
  meta.name = record.name;
  meta.description = record.description ?? '';
  meta.trigger_type = record.trigger_type;
  meta.inbox_ids = [...(record.inbox_ids ?? [])];
  meta.cooldown_minutes = record.cooldown_minutes ?? null;

  // Deep clone: sharing the record's objects would make every edit mutate both sides of the
  // isDirty comparison, so the editor would never notice its own changes.
  const draft = JSON.parse(JSON.stringify(record.draft_definition ?? {}));
  definition.start_node_id = draft.start_node_id ?? null;
  definition.entry_conditions = draft.entry_conditions ?? [];
  definition.nodes = draft.nodes ?? {};
};

const nextNodeId = type => {
  let index = 1;
  while (definition.nodes[`${type}_${index}`]) index += 1;
  return `${type}_${index}`;
};

const addNode = type => {
  const id = nextNodeId(type);
  const count = Object.keys(definition.nodes).length;
  definition.nodes[id] = {
    type,
    ...NODE_DEFAULTS[type](),
    position: {
      x: 80 + (count % 3) * 300,
      y: 80 + Math.floor(count / 3) * 200,
    },
  };
  definition.start_node_id ??= id;
  selectedNodeId.value = id;
};

// Every edge pointing at a removed node has to go too, or publish fails on a dangling target.
const deleteNode = id => {
  delete definition.nodes[id];
  Object.values(definition.nodes).forEach(node => {
    outgoingEdges(node).forEach(edge => {
      if (edgeTarget(node, edge.handle) === id)
        setEdgeTarget(node, edge.handle, null);
    });
  });
  selectedNodeId.value = null;
};

const onConnect = ({ source, sourceHandle, target }) => {
  const node = definition.nodes[source];
  if (node && sourceHandle) setEdgeTarget(node, sourceHandle, target);
};

const onEdgesChange = changes => {
  changes
    .filter(change => change.type === 'remove')
    .forEach(change => {
      const [source, handle] = change.id.split(':');
      const node = definition.nodes[source];
      if (node) setEdgeTarget(node, handle, null);
    });
};

const onNodeDragStop = ({ node }) => {
  const target = definition.nodes[node.id];
  if (target) target.position = { x: node.position.x, y: node.position.y };
};

const tidy = () => {
  const graph = new dagre.graphlib.Graph();
  graph.setDefaultEdgeLabel(() => ({}));
  graph.setGraph({ rankdir: 'TB', nodesep: 60, ranksep: 90 });

  Object.keys(definition.nodes).forEach(id =>
    graph.setNode(id, { width: NODE_WIDTH, height: NODE_HEIGHT })
  );
  flowEdges.value.forEach(edge => graph.setEdge(edge.source, edge.target));
  dagre.layout(graph);

  Object.entries(definition.nodes).forEach(([id, node]) => {
    const laid = graph.node(id);
    node.position = { x: laid.x - NODE_WIDTH / 2, y: laid.y - NODE_HEIGHT / 2 };
  });
  setTimeout(() => fitView({ padding: 0.2 }), 0);
};

const save = async () => {
  isSaving.value = true;
  try {
    const payload = {
      id: flowId,
      ...meta,
      draft_definition: JSON.parse(JSON.stringify(definition)),
    };
    flow.value = (await flowsStore.update(payload)) ?? flow.value;
    useAlert(t('FLOWS.EDITOR.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error, t('FLOWS.EDITOR.SAVE_ERROR')));
  } finally {
    isSaving.value = false;
  }
};

const publish = async () => {
  isSaving.value = true;
  try {
    if (isDirty.value) await save();
    flow.value = await flowsStore.publish(flowId);
    useAlert(
      t('FLOWS.EDITOR.PUBLISHED', {
        version: flow.value.published_version_number,
      })
    );
  } catch (error) {
    useAlert(errorMessage(error, t('FLOWS.EDITOR.PUBLISH_ERROR')));
  } finally {
    isSaving.value = false;
  }
};

const goBack = () => router.push({ name: 'flows_list' });

watch(
  () => definition.nodes,
  () => {
    if (selectedNodeId.value && !definition.nodes[selectedNodeId.value]) {
      selectedNodeId.value = null;
    }
  },
  { deep: true }
);

onMounted(async () => {
  store.dispatch('teams/get');
  store.dispatch('inboxes/get');
  store.dispatch('agents/get');
  await load();
  setTimeout(() => fitView({ padding: 0.2 }), 0);
});
</script>

<template>
  <!-- The dashboard shell renders this straight into a flex row, so the page has to claim the
       row itself; min-w-0 lets the canvas shrink instead of forcing the row wider. -->
  <div class="flex h-full w-full min-w-0 flex-1 flex-col">
    <header
      class="flex flex-wrap items-center gap-3 border-b border-n-weak px-4 py-3"
    >
      <Button
        icon="i-lucide-arrow-left"
        size="sm"
        variant="ghost"
        @click="goBack"
      />
      <Input v-model="meta.name" size="sm" class="w-56 shrink-0" />
      <Select
        v-model="meta.trigger_type"
        :options="triggerOptions"
        class="w-56 shrink-0"
      />
      <Input
        v-if="meta.trigger_type === 'webwidget_triggered'"
        v-model.number="meta.cooldown_minutes"
        type="number"
        size="sm"
        class="w-40 shrink-0"
        :placeholder="t('FLOWS.EDITOR.COOLDOWN')"
      />
      <div class="w-64 shrink-0">
        <TagMultiSelectComboBox
          v-model="meta.inbox_ids"
          :options="inboxOptions"
          :placeholder="t('FLOWS.EDITOR.INBOXES')"
          :search-placeholder="t('FLOWS.EDITOR.INBOXES_SEARCH')"
        />
      </div>

      <span
        v-if="flow?.published_version_number"
        class="rounded px-2 py-1 text-xs text-n-slate-11 bg-n-alpha-2"
      >
        {{
          t('FLOWS.EDITOR.LIVE_VERSION', {
            version: flow.published_version_number,
          })
        }}
      </span>
      <span
        v-else
        class="rounded px-2 py-1 text-xs text-n-amber-12 bg-n-amber-3"
      >
        {{ t('FLOWS.EDITOR.NEVER_PUBLISHED') }}
      </span>

      <div class="ms-auto flex items-center gap-2">
        <Button
          :label="t('FLOWS.EDITOR.TIDY')"
          icon="i-lucide-layout-grid"
          size="sm"
          variant="faded"
          @click="tidy"
        />
        <Button
          :label="t('FLOWS.EDITOR.SAVE_DRAFT')"
          size="sm"
          variant="faded"
          :is-loading="isSaving"
          :disabled="!isDirty"
          @click="save"
        />
        <Button
          :label="t('FLOWS.EDITOR.PUBLISH')"
          size="sm"
          :is-loading="isSaving"
          @click="publish"
        />
      </div>
    </header>

    <div
      v-if="!meta.inbox_ids.length"
      class="border-b border-n-weak bg-n-amber-3 px-4 py-2 text-xs text-n-amber-12"
    >
      {{ t('FLOWS.EDITOR.NO_INBOX') }}
    </div>

    <div
      v-if="hasUnpublishedChanges"
      class="border-b border-n-weak bg-n-amber-3 px-4 py-2 text-xs text-n-amber-12"
    >
      {{ t('FLOWS.EDITOR.UNPUBLISHED_CHANGES') }}
    </div>

    <div class="flex min-h-0 flex-1">
      <aside
        class="flex w-52 shrink-0 flex-col gap-3 overflow-y-auto border-e border-n-weak p-3"
      >
        <div class="flex flex-col gap-1">
          <span
            class="text-xs font-medium uppercase tracking-wide text-n-slate-10"
          >
            {{ t('FLOWS.EDITOR.ADD_NODE') }}
          </span>
          <button
            v-for="type in NODE_TYPES"
            :key="type"
            class="flex items-center gap-2 rounded-lg px-2 py-1.5 text-start text-sm text-n-slate-12 hover:bg-n-alpha-2"
            @click="addNode(type)"
          >
            <Icon :icon="NODE_ICONS[type]" class="size-4 text-n-slate-11" />
            {{ t(`FLOWS.NODE_TYPES.${type.toUpperCase()}`) }}
          </button>
        </div>

        <div class="flex flex-col gap-2 border-t border-n-weak pt-3">
          <span
            class="text-xs font-medium uppercase tracking-wide text-n-slate-10"
          >
            {{ t('FLOWS.EDITOR.ENTRY_CONDITIONS') }}
          </span>
          <p class="text-xs text-n-slate-10">
            {{ t('FLOWS.EDITOR.ENTRY_CONDITIONS_HINT') }}
          </p>
          <ConditionRows v-model="definition.entry_conditions" />
        </div>
      </aside>

      <div class="relative min-w-0 flex-1">
        <VueFlow
          :nodes="flowNodes"
          :edges="flowEdges"
          :default-viewport="{ zoom: 0.85 }"
          :delete-key-code="['Backspace', 'Delete']"
          fit-view-on-init
          @connect="onConnect"
          @edges-change="onEdgesChange"
          @node-drag-stop="onNodeDragStop"
          @node-click="selectedNodeId = $event.node.id"
          @pane-click="selectedNodeId = null"
        >
          <Background pattern-color="#94a3b8" :gap="16" />
          <Controls />
          <template #node-flow="nodeProps">
            <FlowNode
              v-bind="nodeProps"
              :selected="nodeProps.id === selectedNodeId"
            />
          </template>
        </VueFlow>

        <div
          v-if="!Object.keys(definition.nodes).length"
          class="pointer-events-none absolute inset-0 flex items-center justify-center"
        >
          <p class="text-sm text-n-slate-10">{{ t('FLOWS.EDITOR.EMPTY') }}</p>
        </div>
      </div>

      <NodeInspector
        v-if="selectedNode"
        :node="selectedNode"
        :node-id="selectedNodeId"
        :is-start="selectedNodeId === definition.start_node_id"
        :teams="teams"
        :agents="agents"
        @update-node="applyNodeUpdate"
        @delete="deleteNode(selectedNodeId)"
        @make-start="definition.start_node_id = selectedNodeId"
      />
    </div>
  </div>
</template>
