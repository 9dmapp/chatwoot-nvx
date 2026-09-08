# An immutable snapshot of a flow's graph. Sessions hold on to the version they started on,
# so republishing a flow never re-routes a conversation that is already mid-flow.
# == Schema Information
#
# Table name: flow_versions
#
#  id         :bigint           not null, primary key
#  definition :jsonb            not null
#  version    :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  flow_id    :bigint           not null
#
# Indexes
#
#  index_flow_versions_on_account_id           (account_id)
#  index_flow_versions_on_flow_id              (flow_id)
#  index_flow_versions_on_flow_id_and_version  (flow_id,version) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (flow_id => flows.id) ON DELETE => cascade
#
class FlowVersion < ApplicationRecord
  belongs_to :account
  belongs_to :flow

  validates :version, presence: true, uniqueness: { scope: :flow_id }
  validates :definition, presence: true

  def nodes
    definition['nodes'] || {}
  end

  def node(node_id)
    nodes[node_id]
  end

  def start_node_id
    definition['start_node_id']
  end

  def entry_conditions
    definition['entry_conditions'] || []
  end
end
