# One chat session that ended: a conversation resolved once, with the session labels the agent
# chose at that moment. Reopening the same conversation and closing it again records another
# session rather than editing this one, so the visitor keeps a single continuous thread while
# each visit is still categorised on its own.
# == Schema Information
#
# Table name: conversation_resolutions
#
#  id                :bigint           not null, primary key
#  resolved_at       :datetime         not null
#  session_label_ids :bigint           default([]), not null, is an Array
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  assignee_id       :bigint
#  conversation_id   :bigint           not null
#  inbox_id          :bigint           not null
#
# Indexes
#
#  idx_on_account_id_inbox_id_resolved_at_4b9656687c             (account_id,inbox_id,resolved_at)
#  index_conversation_resolutions_on_account_id_and_resolved_at  (account_id,resolved_at)
#  index_conversation_resolutions_on_conversation_id             (conversation_id)
#  index_conversation_resolutions_on_session_label_ids           (session_label_ids) USING gin
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#
class ConversationResolution < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :assignee, class_name: 'User', optional: true

  validates :resolved_at, presence: true

  scope :resolved_between, ->(range) { range.present? ? where(resolved_at: range) : all }
  scope :for_inbox, ->(inbox_id) { inbox_id.present? ? where(inbox_id: inbox_id) : all }

  # Counts each session once per label the agent gave it, broken down by inbox, which is the
  # shape the insights page reads. A session closed without a label contributes to no label and
  # is counted separately.
  def self.count_by_inbox_and_label
    from(Arel.sql("#{table_name}, unnest(session_label_ids) AS session_label_id"))
      .group(Arel.sql('inbox_id'), Arel.sql('session_label_id'))
      .count
  end

  def self.unlabelled_count_by_inbox
    where(session_label_ids: []).group(:inbox_id).count
  end
end
