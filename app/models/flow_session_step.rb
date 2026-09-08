# Append-only trace of the nodes a session walked through.
# == Schema Information
#
# Table name: flow_session_steps
#
#  id              :bigint           not null, primary key
#  metadata        :jsonb            not null
#  node_type       :string           not null
#  created_at      :datetime         not null
#  account_id      :bigint           not null
#  flow_session_id :bigint           not null
#  node_id         :string           not null
#
# Indexes
#
#  index_flow_session_steps_on_account_id                      (account_id)
#  index_flow_session_steps_on_flow_session_id                 (flow_session_id)
#  index_flow_session_steps_on_flow_session_id_and_created_at  (flow_session_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (flow_session_id => flow_sessions.id) ON DELETE => cascade
#
class FlowSessionStep < ApplicationRecord
  belongs_to :account
  belongs_to :flow_session
end
