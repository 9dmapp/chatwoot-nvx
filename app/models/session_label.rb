# A reason a chat session can be closed for. Agents pick from these when resolving; the choice is
# recorded against that session only, so a visitor who comes back about something else is
# categorised afresh without anyone having to undo the last visit's answer.
# == Schema Information
#
# Table name: session_labels
#
#  id          :bigint           not null, primary key
#  archived_at :datetime
#  description :string
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_session_labels_on_account_id_and_archived_at  (account_id,archived_at)
#  index_session_labels_on_account_id_and_title        (account_id,title) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#
class SessionLabel < ApplicationRecord
  belongs_to :account

  validates :title, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

  scope :active, -> { where(archived_at: nil) }

  def archived?
    archived_at.present?
  end
end
