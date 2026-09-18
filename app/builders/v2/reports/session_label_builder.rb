# What chat sessions were about, per inbox, over a date range.
#
# Reads the session labels an agent chose when closing each session, so a visitor who comes back
# about something else is counted separately under the new reason. Counting the conversation's
# current labels instead - which is what the built-in label report does - would credit every
# resolution of a returning visitor to every reason they had ever had.
class V2::Reports::SessionLabelBuilder
  include DateRangeHelper

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    { inboxes: inboxes.map { |inbox| inbox_report(inbox) } }
  end

  private

  # Every inbox with activity in the range, plus any explicitly asked for, so an inbox that
  # handled nothing reads as zero rather than vanishing.
  def inboxes
    @inboxes ||= begin
      scope = account.inboxes.order(:name)
      params[:inbox_id].present? ? scope.where(id: params[:inbox_id]) : scope
    end
  end

  def inbox_report(inbox)
    counts = label_counts_by_inbox[inbox.id] || {}
    unlabelled = unlabelled_by_inbox[inbox.id] || 0

    {
      inbox_id: inbox.id,
      inbox_name: inbox.name,
      # Sessions, not label applications: a session given two reasons is still one session, so
      # these cannot be derived by summing the counts below.
      total_sessions: sessions_by_inbox[inbox.id] || 0,
      unlabelled: unlabelled,
      labels: counts
        .sort_by { |label_id, count| [-count, label_titles[label_id].to_s] }
        .map { |label_id, count| { id: label_id, label: label_titles[label_id], count: count } }
    }
  end

  def scope
    @scope ||= ConversationResolution.where(account_id: account.id).resolved_between(range).for_inbox(params[:inbox_id])
  end

  def label_counts_by_inbox
    @label_counts_by_inbox ||= scope.count_by_inbox_and_label.each_with_object({}) do |((inbox_id, label_id), count), hash|
      (hash[inbox_id] ||= {})[label_id] = count
    end
  end

  def unlabelled_by_inbox
    @unlabelled_by_inbox ||= scope.unlabelled_count_by_inbox
  end

  def sessions_by_inbox
    @sessions_by_inbox ||= scope.group(:inbox_id).count
  end

  # Titles are looked up including archived labels: a report of a past month has to keep its
  # categories even after the list has been tidied up.
  def label_titles
    @label_titles ||= account.session_labels.pluck(:id, :title).to_h
  end
end
