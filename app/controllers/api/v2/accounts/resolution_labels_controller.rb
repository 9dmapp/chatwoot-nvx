# Counts resolutions by the labels they carried at the moment they were resolved.
#
# Kept apart from ReportsController because it reads conversation_resolutions rather than the
# conversation's present labels, which is the whole point of it: a conversation reopened and
# re-labelled is counted once per resolution, not once per label it has ever carried.
class Api::V2::Accounts::ResolutionLabelsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    render json: V2::Reports::ResolutionLabelBuilder.new(
      account: Current.account,
      params: params.permit(:since, :until, :inbox_id)
    ).build
  end

  private

  def check_authorization
    authorize :report, :view?
  end
end
