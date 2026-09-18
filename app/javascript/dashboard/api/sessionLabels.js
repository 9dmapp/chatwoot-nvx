import ApiClient from './ApiClient';

class SessionLabelsAPI extends ApiClient {
  constructor() {
    super('session_labels', { accountScoped: true });
  }
}

export default new SessionLabelsAPI();
