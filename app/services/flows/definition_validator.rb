# Validates the shape of a flow graph. A blank definition is allowed so a flow can be created
# before it is built; anything present must be a complete graph, since publishing it makes it
# the thing the engine walks against live conversations.
class Flows::DefinitionValidator
  NODE_TYPES = %w[send_message quick_replies collect_input condition delay add_label assign_team assign_agent
                  change_status handoff end].freeze
  # Only the content types the widget and the channels can actually render a prompt for.
  INPUT_CONTENT_TYPES = %w[text input_email].freeze
  BUTTON_TYPES = [Flows::NodeButtons::REPLY, Flows::NodeButtons::LINK].freeze
  DELAY_RANGE = (1..43_200) # minutes: 1 minute to 30 days

  def initialize(definition)
    @definition = definition
    @errors = []
  end

  def errors
    return ['must be an object'] unless @definition.is_a?(Hash)
    return [] if @definition.blank?

    validate_shape
    return @errors if @errors.any?

    nodes.each { |node_id, node| validate_node(node_id, node) }
    @errors
  end

  private

  def nodes
    @definition['nodes']
  end

  def validate_shape
    @errors << 'nodes must be an object keyed by node id' if !nodes.is_a?(Hash) || nodes.blank?
    @errors << 'start_node_id is required' if @definition['start_node_id'].blank?
    return if @errors.any?

    @errors << "start_node_id #{@definition['start_node_id']} is not a known node" if nodes[@definition['start_node_id']].blank?
  end

  def validate_node(node_id, node)
    return @errors << "node #{node_id} must be an object" unless node.is_a?(Hash)

    type = node['type']
    return @errors << "node #{node_id} has unsupported type #{type.inspect}" unless NODE_TYPES.include?(type)

    validate_edges(node_id, node)
    validate_timeout(node_id, node)
    validate_params(node_id, node, type)
  end

  def validate_params(node_id, node, type)
    case type
    when 'send_message' then validate_message(node_id, node)
    when 'quick_replies' then validate_quick_replies(node_id, node)
    when 'collect_input' then validate_collect_input(node_id, node)
    when 'condition' then validate_condition(node_id, node)
    when 'delay' then validate_delay(node_id, node)
    end
  end

  # A blank edge ends the flow, so only the targets that are actually set need to resolve.
  def validate_edges(node_id, node)
    targets = [node['next'], node['next_true'], node['next_false'], node['fallback_next'], node['timeout_next']]
    targets += option_targets(node)

    targets.compact_blank.uniq.each do |target|
      @errors << "node #{node_id} points at unknown node #{target}" if nodes[target].blank?
    end
  end

  # Only reply buttons branch the flow; a link button just opens a URL.
  def option_targets(node)
    Flows::NodeButtons.replies(node).filter_map { |button| button['next'] if button.is_a?(Hash) }
  rescue StandardError
    []
  end

  # Only nodes that wait on the visitor can time out; a delay already carries its own duration.
  def validate_timeout(node_id, node)
    return if node['timeout_minutes'].blank?

    @errors << "node #{node_id} cannot have a timeout" unless Flows::NodeButtons.waits?(node)
    @errors << "node #{node_id} timeout_minutes must be between #{DELAY_RANGE.min} and #{DELAY_RANGE.max}" unless
      DELAY_RANGE.cover?(node['timeout_minutes'].to_i)
  end

  def validate_content(node_id, node)
    @errors << "node #{node_id} requires content" if node.dig('params', 'content').blank?
  end

  # A message needs something to show: copy, an image, or at least one button.
  def validate_message(node_id, node)
    buttons = node.dig('params', 'buttons')
    return @errors << "node #{node_id} buttons must be a list" unless buttons.nil? || buttons.is_a?(Array)

    if node.dig('params', 'content').blank? && node.dig('params', 'image_url').blank? && Array(buttons).empty?
      @errors << "node #{node_id} requires content, an image or a button"
    end

    Array(buttons).each_with_index { |button, index| validate_button(node_id, button, index) }
  end

  def validate_button(node_id, button, index)
    label = "node #{node_id} button #{index + 1}"
    return @errors << "#{label} must be an object" unless button.is_a?(Hash)

    @errors << "#{label} requires a title" if button['title'].blank?

    type = button['type'].presence || Flows::NodeButtons::REPLY
    return @errors << "#{label} type must be one of #{BUTTON_TYPES.join(', ')}" unless BUTTON_TYPES.include?(type)

    validate_button_target(label, button, type)
  end

  def validate_button_target(label, button, type)
    if type == Flows::NodeButtons::LINK
      @errors << "#{label} requires a url" if button['url'].blank?
    elsif button['value'].blank?
      @errors << "#{label} requires a value"
    end
  end

  def validate_quick_replies(node_id, node)
    validate_content(node_id, node)
    options = node.dig('params', 'options')
    return @errors << "node #{node_id} requires at least one option" if !options.is_a?(Array) || options.blank?

    return if options.all? { |option| option.is_a?(Hash) && option['title'].present? && option['value'].present? }

    @errors << "node #{node_id} options each require a title and a value"
  end

  def validate_collect_input(node_id, node)
    validate_content(node_id, node)
    @errors << "node #{node_id} requires a variable to store the answer in" if node.dig('params', 'variable').blank?

    content_type = node.dig('params', 'content_type')
    return if content_type.blank? || INPUT_CONTENT_TYPES.include?(content_type)

    @errors << "node #{node_id} content_type must be one of #{INPUT_CONTENT_TYPES.join(', ')}"
  end

  def validate_condition(node_id, node)
    @errors << "node #{node_id} requires conditions" if node.dig('params', 'conditions').blank?
    @errors << "node #{node_id} requires next_true or next_false" if node['next_true'].blank? && node['next_false'].blank?
  end

  def validate_delay(node_id, node)
    return if DELAY_RANGE.cover?(node.dig('params', 'minutes').to_i)

    @errors << "node #{node_id} minutes must be between #{DELAY_RANGE.min} and #{DELAY_RANGE.max}"
  end
end
