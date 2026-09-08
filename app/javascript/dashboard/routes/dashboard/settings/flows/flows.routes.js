import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import FlowsIndex from './Index.vue';
import FlowEditor from './Editor.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/flows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => ({ name: 'flows_list', params: to.params }),
        },
        {
          path: 'list',
          name: 'flows_list',
          component: FlowsIndex,
          meta: {
            featureFlag: FEATURE_FLAGS.FLOWS,
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      // The builder is a full-canvas page, so it sits outside the settings chrome.
      path: frontendURL('accounts/:accountId/settings/flows/:flowId/edit'),
      name: 'flows_edit',
      component: FlowEditor,
      meta: {
        featureFlag: FEATURE_FLAGS.FLOWS,
        permissions: ['administrator'],
      },
    },
  ],
};
