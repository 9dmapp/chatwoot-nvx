# Advances a session that is parked on a node waiting for the visitor.
class Flows::ResumeService
  def initialize(session:, message:, reply:)
    @session = session
    @message = message
    @reply = reply
  end

  def perform
    node = @session.current_node
    # Anything else means the session is not actually parked on a question.
    return unless node && Flows::NodeButtons.waits?(node)
    # The sweep may be advancing this same node right now if it carries a timeout.
    return unless @session.claim_parked!(@session.current_node_id)

    node['type'] == 'collect_input' ? collect(node) : answer(node)
  end

  private

  def collect(node)
    @session.store_variable!(node.dig('params', 'variable'), @reply)
    resume(node['next'])
  end

  def answer(node)
    button = matching_button(node)
    return resume(button['next']) if button.present?
    return resume(node['fallback_next']) if node['fallback_next'].present?

    # Free text where a button was expected means the visitor wants something this flow does not
    # cover, and a human is the right destination.
    @session.conversation.bot_handoff!
    @session.finish!(:handed_off)
  end

  def resume(node_id)
    Flows::ExecutionService.new(@session, message: @message).perform(node_id)
  end

  # The web widget reports the button's value; WhatsApp, Facebook and Telegram send the button
  # title back as ordinary message content, so both are accepted.
  def matching_button(node)
    reply = @reply.to_s.strip.downcase
    return if reply.blank?

    Flows::NodeButtons.replies(node).find do |button|
      [button['value'], button['title']].any? { |candidate| candidate.to_s.strip.downcase == reply }
    end
  end
end
