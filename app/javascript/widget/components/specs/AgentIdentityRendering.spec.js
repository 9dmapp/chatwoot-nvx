import { mount, shallowMount } from '@vue/test-utils';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AgentMessage from '../AgentMessage.vue';
import UnreadMessage from '../UnreadMessage.vue';

const maliciousName =
  '<img src="https://example.com/tracker.png" onerror="alert(1)">Agent';
const maliciousCompanyName = '<strong>Example Company</strong>';

const channelConfig = {
  avatarUrl: '',
  enabledFeatures: [],
  websiteName: maliciousCompanyName,
};

describe('agent identity rendering', () => {
  beforeEach(() => {
    window.chatwootWebChannel = channelConfig;
  });

  afterEach(() => {
    delete window.chatwootWebChannel;
  });

  it('never renders the channel name as markup in widget messages', () => {
    const wrapper = shallowMount(AgentMessage, {
      props: {
        message: {
          id: 1,
          attachments: [],
          content: 'Hello',
          content_attributes: {},
          content_type: 'text',
          message_type: 1,
          sender: {
            available_name: maliciousName,
            avatar_url: '',
          },
          showAvatar: true,
        },
      },
    });

    // Bubbles are attributed to the channel, not the agent, so it is the channel name that
    // reaches the avatar. Passing it as a prop is what keeps it data rather than markup.
    expect(wrapper.find('.agent-name').exists()).toBe(false);
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.findComponent(Avatar).props('name')).toBe(
      maliciousCompanyName
    );
  });

  it('renders agent and company names as plain text in unread messages', () => {
    const wrapper = mount(UnreadMessage, {
      props: {
        message: 'Hello',
        showSender: true,
        sender: {
          available_name: maliciousName,
          avatar_url: '',
        },
      },
      global: {
        stubs: { Avatar: true },
        directives: {
          dompurifyHtml: (element, binding) => {
            element.textContent = binding.value;
          },
        },
      },
    });
    const agentName = wrapper.find('.agent--name');
    const companyName = wrapper.find('.company--name');

    expect(agentName.text()).toBe(maliciousName);
    expect(agentName.find('img').exists()).toBe(false);
    expect(companyName.text()).toContain(maliciousCompanyName);
    expect(companyName.find('strong').exists()).toBe(false);
  });
});
