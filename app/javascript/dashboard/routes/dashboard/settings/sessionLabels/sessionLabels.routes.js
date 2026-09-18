import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import SessionLabelsIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/session-labels'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => ({ name: 'session_labels_list', params: to.params }),
        },
        {
          path: 'list',
          name: 'session_labels_list',
          component: SessionLabelsIndex,
          meta: { permissions: ['administrator'] },
        },
      ],
    },
  ],
};
