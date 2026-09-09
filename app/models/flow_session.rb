# == Schema Information
#
# Table name: flow_sessions
#
#  id                  :bigint           not null, primary key
#  ended_at            :datetime
#  resume_at           :datetime
#  status              :integer          default("active"), not null
#  variables           :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  awaiting_message_id :bigint
#  conversation_id     :bigint           not null
#  current_node_id     :string
#  flow_id             :bigint           not null
#  flow_version_id     :bigint           not null
#
# Indexes
#
#  index_flow_sessions_on_account_id           (account_id)
#  index_flow_sessions_on_active_conversation  (conversation_id) UNIQUE WHERE (status = 0)
#  index_flow_sessions_on_conversation_id      (conversation_id)
#  index_flow_sessions_on_due_resume_at        (resume_at) WHERE ((status = 0) AND (resume_at IS NOT NULL))
#  index_flow_sessions_on_flow_id              (flow_id)
#  index_flow_sessions_on_flow_version_id      (flow_version_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (conversation_id => conversations.id) ON DELETE => cascade
#  fk_rails_...  (flow_id => flows.id) ON DELETE => cascade
#  fk_rails_...  (flow_version_id => flow_versions.id) ON DELETE => cascade
#
class FlowSession < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :flow
  belongs_to :flow_version
  has_many :steps, class_name: 'FlowSessionStep', dependent: :delete_all

  enum status: { active: 0, completed: 1, handed_off: 2, aborted: 3 }

  def current_node
    return if current_node_id.blank?

    flow_version.node(current_node_id)
  end

  # Parks the session on a node until the visitor answers, a deadline passes, or either.
  def park!(node_id, message: nil, resume_at: nil)
    update!(current_node_id: node_id, awaiting_message_id: message&.id, resume_at: resume_at)
  end

  # Both paths that can wake a parked session - the visitor's reply and the timeout sweep - claim
  # it by clearing the parked node under a row lock. Exactly one of them finds the row still
  # parked on that node, so a reply landing as the timeout fires cannot advance the flow twice.
  # resume_at alone cannot serve as the token: a question without a timeout never sets one.
  def claim_parked!(node_id)
    with_lock do
      next false unless active? && current_node_id == node_id

      update!(current_node_id: nil, awaiting_message_id: nil, resume_at: nil)
      true
    end
  end

  def finish!(status)
    update!(status: status, ended_at: Time.current, awaiting_message_id: nil, resume_at: nil)
  end

  def store_variable!(key, value)
    update!(variables: variables.merge(key => value))
  end
end
