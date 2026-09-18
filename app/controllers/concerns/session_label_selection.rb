# Reads the session labels an agent picked while resolving, and refuses the resolve when the
# inbox insists on one.
module SessionLabelSelection
  extend ActiveSupport::Concern

  private

  # Only the dashboard is asked. A request carrying an api_access_token is an integration or a
  # bot: there is no one to prompt, and those resolves have to keep working.
  # Halts the action when a label is required and none was picked; otherwise hands the agent's
  # choice to ConversationResolutionListener, which records it once the status change lands.
  def apply_session_label_selection
    return unless resolving?

    if requires_session_label? && requested_session_label_ids.empty?
      return render_could_not_create_error(I18n.t('errors.conversations.session_label_required'))
    end

    Current.session_label_ids = requested_session_label_ids
  end

  def requires_session_label?
    !authenticate_by_access_token? && @conversation.inbox.require_session_label?
  end

  # A blank status means the caller is toggling, which resolves an open conversation.
  def resolving?
    params[:status].to_s == 'resolved' || (params[:status].blank? && @conversation.open?)
  end

  # Resolved through the account, so an id from another account is simply not found rather than
  # trusted.
  def requested_session_label_ids
    @requested_session_label_ids ||= Current.account.session_labels.where(id: params[:session_label_ids]).ids
  end
end
