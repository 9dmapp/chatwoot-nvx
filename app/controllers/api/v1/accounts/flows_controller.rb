class Api::V1::Accounts::FlowsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_flow, only: [:show, :update, :destroy, :publish]

  def index
    @flows = Current.account.flows.order(:id)
  end

  def show; end

  def create
    @flow = Current.account.flows.new(flow_params)
    return render_could_not_create_error(@flow.errors.messages) unless @flow.save

    render :show
  end

  def update
    # Assigning inbox_ids on a persisted record writes the join rows immediately, before the
    # record is validated, so the whole update runs in one transaction that can roll them back.
    Flow.transaction do
      @flow.assign_attributes(flow_params.except(:inbox_ids))
      @flow.inbox_ids = requested_inbox_ids if params.key?(:inbox_ids)
      @flow.save!
    end
    render :show
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
    render_could_not_create_error(@flow.errors.messages.presence || { inboxes: ['are invalid'] })
  end

  def destroy
    @flow.destroy!
    head :ok
  end

  # Freezes the current draft as the version live conversations will walk.
  def publish
    @flow.publish!
    render :show
  rescue ActiveRecord::RecordInvalid => e
    render_could_not_create_error(e.record.errors.messages)
  end

  private

  def flow_params
    permitted = params.permit(:name, :description, :trigger_type, :active, :cooldown_minutes, inbox_ids: [])
    # The graph is free-form JSON by design; Flows::DefinitionValidator is what constrains it,
    # so listing every node shape as strong params here would only duplicate that.
    permitted[:draft_definition] = draft_definition if params.key?(:draft_definition)
    permitted
  end

  def draft_definition
    definition = params[:draft_definition]
    definition.is_a?(ActionController::Parameters) ? definition.to_unsafe_h : definition
  end

  # Resolved through the account rather than taken at face value, so an id from another account
  # is simply not found instead of being attached and rejected afterwards.
  def requested_inbox_ids
    Current.account.inboxes.where(id: params[:inbox_ids]).ids
  end

  def fetch_flow
    @flow = Current.account.flows.find(params[:id])
  end
end
