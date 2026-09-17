# Counts resolutions by the labels they were resolved with.
#
# This reads the frozen snapshots in conversation_resolutions rather than the labels currently on
# conversations, so a conversation reopened and resolved three times counts three times, each under
# whatever it was about at the time. The built-in label report cannot do this: it joins resolution
# events to a conversation's present labels, so those three resolutions would each be counted
# against all three labels.
class V2::Reports::ResolutionLabelBuilder
  include DateRangeHelper

  attr_reader :account, :params

  def initialize(account:, params:)
    @account = account
    @params = params
  end

  def build
    counts = scope.count_by_label
    labelled = counts.values.sum

    {
      labels: counts.sort_by { |label, count| [-count, label] }.map { |label, count| { label: label, count: count } },
      unlabelled: scope.where(labels: []).count,
      total_resolutions: scope.count,
      total_label_applications: labelled
    }
  end

  private

  def scope
    @scope ||= ConversationResolution
               .where(account_id: account.id)
               .resolved_between(range)
               .for_inbox(params[:inbox_id])
  end
end
