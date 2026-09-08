# Advances a session whose deadline has passed: a delay that finished waiting, or a question the
# visitor never answered.
class Flows::TimeoutService
  def initialize(session)
    @session = session
  end

  def perform
    return unless @session.active?

    node = @session.current_node
    return @session.finish!(:aborted) if node.blank?
    # The visitor may have answered between the sweep selecting this session and this job
    # running, in which case the reply already claimed the node and owns the next step.
    return unless @session.claim_parked!(@session.current_node_id)

    Flows::ExecutionService.new(@session).perform(next_node_id(node))
  end

  private

  # A delay simply continues. A question that timed out takes its timeout edge, and a blank one
  # ends the flow rather than leaving the session parked forever.
  def next_node_id(node)
    node['type'] == 'delay' ? node['next'] : node['timeout_next']
  end
end
