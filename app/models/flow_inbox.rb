# Scopes a flow to the inboxes it runs on. Deleting an inbox removes the attachment rather than
# leaving the flow pointing at an inbox that no longer exists.
# == Schema Information
#
# Table name: flow_inboxes
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  flow_id    :bigint           not null
#  inbox_id   :bigint           not null
#
# Indexes
#
#  index_flow_inboxes_on_account_id            (account_id)
#  index_flow_inboxes_on_flow_id               (flow_id)
#  index_flow_inboxes_on_flow_id_and_inbox_id  (flow_id,inbox_id) UNIQUE
#  index_flow_inboxes_on_inbox_id              (inbox_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (flow_id => flows.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#
class FlowInbox < ApplicationRecord
  belongs_to :account
  belongs_to :flow
  belongs_to :inbox

  before_validation :ensure_account_id
  # Every path that attaches an inbox creates one of these rows, and assigning inbox_ids on a
  # persisted flow writes them before the flow itself is validated. Checking the boundary here is
  # what actually stops a cross-account attachment rather than reporting it after the fact.
  validate :inbox_belongs_to_flow_account

  private

  def ensure_account_id
    self.account_id ||= inbox&.account_id
  end

  def inbox_belongs_to_flow_account
    return if inbox.blank? || flow.blank?
    return if inbox.account_id == flow.account_id

    errors.add(:inbox, 'must belong to the same account as the flow')
  end
end
