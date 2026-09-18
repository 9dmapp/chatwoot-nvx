class Api::V1::Accounts::SessionLabelsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_session_label, only: [:update, :destroy]

  def index
    @session_labels = Current.account.session_labels.order(:title)
  end

  def create
    @session_label = Current.account.session_labels.new(session_label_params)
    return render_could_not_create_error(@session_label.errors.messages) unless @session_label.save

    render :show
  end

  def update
    return render_could_not_create_error(@session_label.errors.messages) unless @session_label.update(session_label_params)

    render :show
  end

  # Archived rather than destroyed: sessions already closed under this label still refer to it,
  # and the insights for a past month must keep their categories.
  def destroy
    @session_label.update!(archived_at: Time.zone.now)
    head :ok
  end

  private

  def session_label_params
    params.require(:session_label).permit(:title, :description, :archived_at)
  end

  def fetch_session_label
    @session_label = Current.account.session_labels.find(params[:id])
  end
end
