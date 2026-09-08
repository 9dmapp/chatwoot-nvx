# == Schema Information
#
# Table name: flows
#
#  id                   :bigint           not null, primary key
#  active               :boolean          default(FALSE), not null
#  cooldown_minutes     :integer
#  description          :text
#  draft_definition     :jsonb            not null
#  name                 :string           not null
#  trigger_type         :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  published_version_id :bigint
#
# Indexes
#
#  index_flows_on_account_id                              (account_id)
#  index_flows_on_account_id_and_trigger_type_and_active  (account_id,trigger_type,active)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (published_version_id => flow_versions.id) ON DELETE => nullify
#
class Flow < ApplicationRecord
  TRIGGER_TYPES = %w[conversation_created message_created webwidget_triggered].freeze
  COOLDOWN_RANGE = (1..43_200) # minutes: 1 minute to 30 days

  belongs_to :account
  belongs_to :published_version, class_name: 'FlowVersion', optional: true
  has_many :versions, class_name: 'FlowVersion', dependent: :destroy
  has_many :sessions, class_name: 'FlowSession', dependent: :destroy
  has_many :flow_inboxes, dependent: :destroy
  has_many :inboxes, through: :flow_inboxes

  validates :name, presence: true
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }
  validates :cooldown_minutes, numericality: { only_integer: true, in: COOLDOWN_RANGE }, allow_nil: true
  validate :draft_definition_shape
  validate :inbox_attached_when_active

  # An unpublished flow has no graph to walk, so it is never a trigger candidate.
  scope :published, -> { where(active: true).where.not(published_version_id: nil) }
  # A flow only runs on the inboxes it is attached to.
  scope :for_inbox, ->(inbox_id) { where(id: FlowInbox.where(inbox_id: inbox_id).select(:flow_id)) }

  # Entry conditions use the automation rule condition format, so both features share the same
  # operators, attributes and validation.
  def conditions
    published_version&.entry_conditions || []
  end

  # Freezes the current draft as a new immutable version and points the flow at it. `active` is
  # left alone: publishing an edit to a paused flow should not silently switch it back on.
  # An empty draft is rejected by FlowVersion's own validation rather than checked here.
  def publish!
    transaction do
      version = versions.create!(account: account, version: versions.maximum(:version).to_i + 1, definition: draft_definition)
      update!(published_version: version)
      version
    end
  end

  private

  def draft_definition_shape
    Flows::DefinitionValidator.new(draft_definition).errors.each { |error| errors.add(:draft_definition, error) }
  end

  # A live flow with no inbox would listen to nothing, which reads as broken rather than paused.
  def inbox_attached_when_active
    errors.add(:inboxes, 'must include at least one inbox before a flow can be activated') if active? && inboxes.empty?
  end
end
