# Reads a node's buttons in one shape regardless of how it was authored.
#
# `send_message` carries `params.buttons`, each either a reply button (branches the flow) or a
# link button (opens a URL in a new tab). Flows built before the two node types were merged used
# `quick_replies` with `params.options`, which are reply buttons by another name.
module Flows::NodeButtons
  REPLY = 'reply'.freeze
  LINK = 'link'.freeze

  module_function

  def all(node)
    params = node['params'] || {}
    return legacy_options(params) if node['type'] == 'quick_replies'

    Array(params['buttons'])
  end

  def replies(node)
    all(node).select { |button| button['type'].nil? || button['type'] == REPLY }
  end

  def links(node)
    all(node).select { |button| button['type'] == LINK }
  end

  # A node only parks the session when there is something for the visitor to answer.
  def waits?(node)
    return true if %w[quick_replies collect_input].include?(node['type'])

    node['type'] == 'send_message' && replies(node).any?
  end

  def legacy_options(params)
    Array(params['options']).map { |option| option.merge('type' => REPLY) }
  end
end
