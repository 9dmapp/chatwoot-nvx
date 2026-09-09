export const TRIGGER_TYPES = [
  'conversation_created',
  'message_created',
  'webwidget_triggered',
];

export const CONVERSATION_STATUSES = ['open', 'pending', 'resolved', 'snoozed'];

export const BUTTON_TYPES = ['reply', 'link'];

export const DEFAULT_TIMEOUT_MINUTES = 60;

export const MAX_BUTTONS = 10;

// Only reply buttons branch the flow; link buttons just open a URL in a new tab.
// Mirrors Flows::NodeButtons. Flows authored before send_message absorbed the button node use
// `quick_replies` with `params.options`; reading only `params.buttons` would draw those flows
// with a single "Next" handle and lose their branches on the next save.
//
// These return the stored objects rather than copies, because setEdgeTarget writes each
// button's `next` in place.
const isLegacyOptions = node => node.type === 'quick_replies';

export const replyButtons = node =>
  isLegacyOptions(node)
    ? (node.params?.options ?? [])
    : (node.params?.buttons ?? []).filter(b => !b.type || b.type === 'reply');

export const linkButtons = node =>
  isLegacyOptions(node)
    ? []
    : (node.params?.buttons ?? []).filter(b => b.type === 'link');

// A node parks the session only when it gave the visitor something to answer.
export const waitsForVisitor = node =>
  ['collect_input', 'quick_replies'].includes(node.type) ||
  replyButtons(node).length > 0;

// Kept in step with Flows::DefinitionValidator::NODE_TYPES.
export const NODE_TYPES = [
  'send_message',
  'collect_input',
  'condition',
  'delay',
  'add_label',
  'assign_team',
  'assign_agent',
  'change_status',
  'handoff',
  'end',
];

export const NODE_ICONS = {
  send_message: 'i-lucide-message-square',
  quick_replies: 'i-lucide-list',
  collect_input: 'i-lucide-text-cursor-input',
  condition: 'i-lucide-git-branch',
  delay: 'i-lucide-timer',
  add_label: 'i-lucide-tag',
  assign_team: 'i-lucide-users',
  assign_agent: 'i-lucide-user',
  change_status: 'i-lucide-circle-dot',
  handoff: 'i-lucide-hand',
  end: 'i-lucide-flag',
};

export const NODE_DEFAULTS = {
  send_message: () => ({ params: { content: '' } }),
  quick_replies: () => ({
    params: { content: '', options: [{ title: '', value: '' }] },
  }),
  collect_input: () => ({
    params: { content: '', variable: '', content_type: 'text' },
  }),
  condition: () => ({ params: { conditions: [] } }),
  delay: () => ({ params: { minutes: 60 } }),
  add_label: () => ({ params: { labels: [] } }),
  assign_team: () => ({ params: { team_id: null } }),
  assign_agent: () => ({ params: { agent_id: null } }),
  change_status: () => ({ params: { status: 'open' } }),
  handoff: () => ({ params: {} }),
  end: () => ({ params: {} }),
};

export const DELAY_RANGE = { min: 1, max: 43200 };

export const MAX_QUICK_REPLY_OPTIONS = 10;

// The outgoing edges a node should draw, one per source handle. Quick replies grow a handle per
// option, and any waiting node grows one more once it is given a timeout.
export const outgoingEdges = node => {
  const edges = [];

  if (node.type === 'condition') {
    edges.push({ handle: 'next_true', label: 'True' });
    edges.push({ handle: 'next_false', label: 'False' });
  } else if (['handoff', 'end'].includes(node.type)) {
    return edges;
  } else if (replyButtons(node).length) {
    replyButtons(node).forEach((button, index) => {
      edges.push({
        handle: `option:${index}`,
        label: button.title || `Button ${index + 1}`,
      });
    });
    edges.push({ handle: 'fallback_next', label: 'No match' });
  } else {
    edges.push({ handle: 'next', label: 'Next' });
  }

  if (waitsForVisitor(node) && node.timeout_minutes) {
    edges.push({ handle: 'timeout_next', label: 'Timeout' });
  }

  return edges;
};

const optionIndex = handle => Number(handle.split(':')[1]);

export const edgeTarget = (node, handle) =>
  handle.startsWith('option:')
    ? replyButtons(node)[optionIndex(handle)]?.next
    : node[handle];

export const setEdgeTarget = (node, handle, target) => {
  if (!handle.startsWith('option:')) {
    node[handle] = target;
    return;
  }

  const button = replyButtons(node)[optionIndex(handle)];
  if (button) button.next = target;
};

// Model validation returns { field: [messages] } while controller guards return a plain string,
// so both shapes have to collapse to something a toast can show.
export const errorMessage = (error, fallback) => {
  const payload = error?.response?.data?.error;
  if (!payload) return fallback;
  if (typeof payload === 'string') return payload;

  return Object.values(payload).flat().join('. ') || fallback;
};

// Postgres returns jsonb keys in its own order (shortest first), which never matches the order
// the editor builds them in, so a plain JSON.stringify comparison reports differences that do
// not exist. Sorting keys throughout makes "has this actually changed?" answerable.
const canonical = value => {
  if (Array.isArray(value)) return value.map(canonical);
  if (value === null || typeof value !== 'object') return value;

  return Object.keys(value)
    .sort()
    .reduce((sorted, key) => {
      sorted[key] = canonical(value[key]);
      return sorted;
    }, {});
};

export const stableStringify = value => JSON.stringify(canonical(value));
