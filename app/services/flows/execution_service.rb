# Walks a flow graph for one session until it reaches a node that waits for the visitor, a node
# that ends the flow, or the step budget.
class Flows::ExecutionService
  include Events::Types

  # Replies after the first are paced apart, with the typing bubble showing in between, so a
  # multi-step flow reads like someone answering rather than a wall of text landing at once.
  # This deliberately holds the worker: a flow walk is short and the pause is what makes it feel
  # authored. ActionCableListener is synchronous, so the bubble is on screen before the wait.
  PACING_SECONDS = 0.7

  # A single tick may not walk more nodes than this. A definition whose edges form a cycle would
  # otherwise loop forever, so the session is aborted instead.
  MAX_STEPS_PER_TICK = 50

  def initialize(session, message: nil)
    @session = session
    @message = message
    @conversation = session.conversation
    @account = session.account
    @delivered = 0
  end

  def perform(node_id)
    walk(node_id)
  rescue StandardError => e
    # Without this the session stays active forever, and the partial unique index on live
    # sessions would stop the conversation from ever entering another flow.
    @session.finish!(:aborted)
    @conversation.bot_handoff!
    ChatwootExceptionTracker.new(e, account: @account).capture_exception
  end

  private

  def walk(node_id)
    MAX_STEPS_PER_TICK.times do
      # A blank edge is how a branch ends without an explicit end node.
      return @session.finish!(:completed) if node_id.blank?

      node = @session.flow_version.node(node_id)
      # The node a session was standing on can retire when its flow is edited and republished.
      return @session.finish!(:aborted) if node.blank?

      record_step(node_id, node)
      status, value = execute(node_id, node)

      return @session if status == :suspend
      return @session.finish!(value) if status == :terminate

      node_id = value
    end

    @session.finish!(:aborted)
  end

  # Control nodes decide where the session goes next; everything else is a side effect that
  # continues along `next`.
  def execute(node_id, node)
    # Earlier nodes in this same walk have already written to the row (a sent message touches
    # waiting_since and last activity), so the in-memory copy is stale by now. The action
    # service shares this instance, so reloading here refreshes both.
    @conversation.reload

    case node['type']
    when 'send_message', 'quick_replies'
      deliver(node_id, node)
    when 'collect_input', 'delay'
      park(node_id, node)
      [:suspend, nil]
    when 'condition'
      [:continue, condition_matches?(node_id, node['params']) ? node['next_true'] : node['next_false']]
    when 'handoff'
      @conversation.bot_handoff!
      [:terminate, :handed_off]
    when 'end'
      [:terminate, :completed]
    else
      perform_action(node_id, node)
      [:continue, node['next']]
    end
  end

  # A message node only waits when it gave the visitor reply buttons to answer with. Link
  # buttons open a URL and tell us nothing, so a node carrying only those keeps walking.
  def deliver(node_id, node)
    params = node['params'] || {}
    pace
    message = action_service.send_message(node_id, params, node)
    @delivered += 1
    return [:continue, node['next']] unless Flows::NodeButtons.waits?(node)

    @session.park!(node_id, message: message, resume_at: resume_at_for(node, params))
    [:suspend, nil]
  end

  def park(node_id, node)
    params = node['params'] || {}
    message = nil
    if node['type'] == 'collect_input'
      pace
      message = action_service.ask_for_input(node_id, params)
      @delivered += 1
    end
    @session.park!(node_id, message: message, resume_at: resume_at_for(node, params))
  end

  # The first reply is immediate; everything after it waits behind a typing bubble.
  def pace
    return if @delivered.zero?

    toggle_typing(CONVERSATION_TYPING_ON)
    sleep(PACING_SECONDS)
    toggle_typing(CONVERSATION_TYPING_OFF)
  end

  # The typing broadcast is addressed from a real agent, so it needs one; an inbox with no
  # members still paces, just without the bubble.
  def toggle_typing(event)
    return if typist.blank?

    Rails.configuration.dispatcher.dispatch(event, Time.zone.now, conversation: @conversation, user: typist, is_private: false)
  end

  def typist
    return @typist if defined?(@typist)

    @typist = @conversation.assignee || @conversation.inbox.members.first
  end

  def resume_at_for(node, params)
    return params['minutes'].to_i.minutes.from_now if node['type'] == 'delay'
    return if node['timeout_minutes'].blank?

    node['timeout_minutes'].to_i.minutes.from_now
  end

  def perform_action(node_id, node)
    params = node['params'] || {}

    case node['type']
    when 'send_message' then action_service.send_message(node_id, params)
    when 'add_label' then action_service.add_label(Array(params['labels']))
    when 'assign_team' then action_service.assign_team([params['team_id']])
    when 'assign_agent' then action_service.assign_agent([params['agent_id']])
    when 'change_status' then action_service.change_status([params['status']])
    else
      # The definition validator rejects unknown types before a flow can be published, so this
      # only fires when the validator and the engine have drifted apart in a deploy.
      raise "Unsupported flow node type #{node['type'].inspect}"
    end
  end

  def condition_matches?(node_id, params)
    condition_set = Flows::ConditionSet.new(node_id, @account, params['conditions'])
    options = @message.present? ? { message: @message } : {}
    AutomationRules::ConditionsFilterService.new(condition_set, @conversation, options).perform
  end

  def record_step(node_id, node)
    @session.steps.create!(account_id: @session.account_id, node_id: node_id, node_type: node['type'])
  end

  def action_service
    @action_service ||= Flows::ActionService.new(@session)
  end
end
