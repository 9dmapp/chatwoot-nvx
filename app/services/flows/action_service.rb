class Flows::ActionService < ActionService
  # Values captured by earlier collect_input nodes, referenced as {{name}} in later copy.
  VARIABLE_PATTERN = /\{\{\s*(\w+)\s*\}\}/

  def initialize(session)
    @session = session
    super(session.conversation)
  end

  # A node can carry text, an image, link buttons and reply buttons in any combination, but a
  # single Chatwoot message can only be one content type. Anything visual (image or link buttons)
  # goes out as a card; reply buttons need input_select, which is the only shape the visitor's
  # answer comes back through. A node using both therefore sends the card first, then the prompt.
  def send_message(node_id, params, node)
    replies = Flows::NodeButtons.replies(node)
    links = Flows::NodeButtons.links(node)
    content = interpolate(params['content'])

    # Only one content type fits in a message, so a node carrying both kinds of button sends two:
    # the card holds the image and link buttons, the select holds the copy and reply buttons.
    send_visual(node_id, params['image_url'], replies.any? ? '' : content, links) if params['image_url'].present? || links.any?
    return send_replies(node_id, content, replies) if replies.any?

    create_message(node_id, content: content) if params['image_url'].blank? && links.empty?
  end

  def send_quick_replies(node_id, params, node = nil)
    send_message(node_id, params, node || { 'type' => 'quick_replies', 'params' => params })
  end

  def ask_for_input(node_id, params)
    create_message(node_id, content: interpolate(params['content']),
                            content_type: params['content_type'].presence || :text)
  end

  private

  def send_replies(node_id, content, replies)
    items = replies.map { |button| { title: button['title'], value: button['value'] } }
    create_message(node_id, content: content, content_type: :input_select, items: items)
  end

  # A card is the only shape that renders link buttons, but Chatwoot rejects a card with no
  # actions, so an image on its own goes out as an ordinary message with an image attachment.
  def send_visual(node_id, image_url, caption, links)
    return send_image(node_id, image_url, caption) if links.empty?

    create_message(node_id, content: card_gate(caption, links), content_type: :cards,
                            items: [build_card(image_url, caption, links)])
  end

  def build_card(image_url, caption, links)
    actions = links.map { |button| { text: button['title'], type: 'link', uri: button['url'] } }
    card = { title: '', description: interpolate(caption), actions: actions }
    card[:media_url] = image_url if image_url.present?
    card
  end

  # A card never displays message.content - the widget only uses it to decide whether to draw the
  # bubble at all - so it just has to be non-empty; the visible copy lives on the card itself.
  def card_gate(caption, links)
    interpolate(caption).presence || links.first&.dig('title').presence || ' '
  end

  def send_image(node_id, image_url, caption)
    message = create_message(node_id, content: interpolate(caption))
    message.attachments.create!(account_id: @conversation.account_id, file_type: :image, external_url: image_url)
    message
  end

  # Built directly rather than through Messages::MessageBuilder: the builder only picks up
  # `items` from ActionController::Parameters and would blank the store accessor for the plain
  # hash a service passes. Shaped like the CSAT survey template - no sender, so a flow message
  # is never attributed to an agent in reporting, and still delivered on every channel.
  def create_message(node_id, content:, content_type: :text, items: nil)
    content_attributes = { flow_id: @session.flow_id, flow_session_id: @session.id, flow_node_id: node_id }
    content_attributes[:items] = items if items.present?

    @conversation.messages.create!(
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content_type: content_type,
      content: content,
      content_attributes: content_attributes
    )
  end

  # An unset variable renders empty rather than leaving the raw {{name}} in the visitor's face.
  def interpolate(content)
    content.to_s.gsub(VARIABLE_PATTERN) { @session.variables[Regexp.last_match(1)].to_s }
  end
end
