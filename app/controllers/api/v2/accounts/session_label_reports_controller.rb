# What chat sessions were about, per inbox, over a date range.
#
# Kept apart from ReportsController because it reads the session labels recorded against each
# resolution rather than the labels currently on a conversation - the distinction the whole
# feature exists for.
class Api::V2::Accounts::SessionLabelReportsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: V2::Reports::SessionLabelBuilder.new(
      account: Current.account,
      params: params.permit(:since, :until, :inbox_id)
    ).build
  end

  private

  def check_authorization
    authorize :report, :view?
  end
end
