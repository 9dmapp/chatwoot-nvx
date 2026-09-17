# A conversation resolved once. `labels` is what it carried at that moment, frozen, so reopening
# and re-labelling the same conversation records a second resolution rather than editing the first.
# == Schema Information
#
# Table name: conversation_resolutions
#
#  id              :bigint           not null, primary key
#  labels          :string           default([]), not null, is an Array
#  resolved_at     :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  assignee_id     :bigint
#  conversation_id :bigint           not null
#  inbox_id        :bigint           not null
#
# Indexes
#
#  idx_on_account_id_inbox_id_resolved_at_4b9656687c             (account_id,inbox_id,resolved_at)
#  index_conversation_resolutions_on_account_id_and_resolved_at  (account_id,resolved_at)
#  index_conversation_resolutions_on_conversation_id             (conversation_id)
#  index_conversation_resolutions_on_labels                      (labels) USING gin
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

  # Counts each resolution once per label it carried, which is what "how many chats were about X"
  # asks for. A resolution with no labels contributes to none of them and is reported separately.
  def self.count_by_label
    from(Arel.sql("#{table_name}, unnest(labels) AS label"))
      .group(Arel.sql('label'))
      .order(Arel.sql('count_all DESC'))
      .count
  end
end
