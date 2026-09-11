import FlowsAPI from 'dashboard/api/flows';
import { createStore } from 'dashboard/store/storeFactory';

export const useFlowsStore = createStore({
  name: 'flows',
  type: 'pinia',
  API: FlowsAPI,

  getters: {
    getFlow: state => id => state.records.find(flow => flow.id === Number(id)),
  },

  actions: () => ({
    // Publishing returns the flow with its new version, so the record is replaced rather than
    // refetched; the editor reads published_version_number straight off it.
    // The copy comes back fully formed, so it is appended rather than refetching the list.
    async duplicate(flowId, name) {
      this.setUIFlag({ creatingItem: true });
      try {
        const { data } = await FlowsAPI.duplicate(flowId, name);
        this.records.push(data.payload);
        return data.payload;
      } finally {
        this.setUIFlag({ creatingItem: false });
      }
    },

    async publish(flowId) {
      this.setUIFlag({ updatingItem: true });
      try {
        const { data } = await FlowsAPI.publish(flowId);
        const index = this.records.findIndex(
          flow => flow.id === Number(flowId)
        );
        if (index !== -1) this.records.splice(index, 1, data.payload);
        return data.payload;
      } finally {
        this.setUIFlag({ updatingItem: false });
      }
    },
  }),
});
