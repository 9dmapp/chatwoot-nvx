/* global axios */
import ApiClient from './ApiClient';

class FlowsAPI extends ApiClient {
  constructor() {
    super('flows', { accountScoped: true });
  }

  publish(flowId) {
    return axios.post(`${this.url}/${flowId}/publish`);
  }

  duplicate(flowId, name) {
    return axios.post(`${this.url}/${flowId}/duplicate`, { name });
  }
}

export default new FlowsAPI();
