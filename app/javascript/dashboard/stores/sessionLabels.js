import SessionLabelsAPI from 'dashboard/api/sessionLabels';
import { createStore } from 'dashboard/store/storeFactory';

export const useSessionLabelsStore = createStore({
  name: 'sessionLabels',
  type: 'pinia',
  API: SessionLabelsAPI,

  getters: {
    // Archived labels stay in reports but must not be offered to agents any more.
    active: state => state.records.filter(label => !label.archived_at),
  },
});
