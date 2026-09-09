# Admits a conversation into a flow. This is the only place a session is opened, so the
# exclusivity rule lives here and at the partial unique index behind it.
class Flows::TriggerService
  def initialize(conversation:, message: nil, trigger_type: nil)
    @conversation = conversation
    @message = message
    @account = conversation.account
    # Widget-open triggers have no message, so the type cannot always be inferred from one.
    @trigger_type = trigger_type || (message.present? ? 'message_created' : 'conversation_created')
  end

  def perform
    flow = matching_flow
    return if flow.blank?

    version = flow.published_version
    session = FlowSession.create!(account: @account, conversation: @conversation, flow: flow, flow_version: version)
    Flows::ExecutionService.new(session, message: @message).perform(version.start_node_id)
  rescue ActiveRecord::RecordNotUnique
    # Two events raced past the router's exclusivity check. The index is the authority and the
    # loser simply does not open a second session.
    nil
  end

  private

  # First published flow attached to this inbox wins, so a conversation is only ever admitted to one.
  def matching_flow
    Flow.published
        .for_inbox(@conversation.inbox_id)
        .where(account_id: @account.id, trigger_type: @trigger_type)
        .order(:id)
        .detect { |flow| conditions_match?(flow) }
  end

  # A flow with no entry conditions runs for every event of its trigger type, which is what a
  # plain welcome flow wants.
  def conditions_match?(flow)
    return true if flow.conditions.blank?

    condition_set = Flows::ConditionSet.new(flow.id, @account, flow.conditions)
    options = @message.present? ? { message: @message } : {}
    AutomationRules::ConditionsFilterService.new(condition_set, @conversation, options).perform
  end
end
