class CreateFlows < ActiveRecord::Migration[7.1]
  def change
    create_flows
    create_flow_versions
    create_flow_sessions
    create_flow_session_steps
  end

  private

  def create_flows
    create_table :flows do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.text :description
      t.string :trigger_type, null: false
      t.boolean :active, null: false, default: false
      t.jsonb :draft_definition, null: false, default: {}
      t.bigint :published_version_id

      t.timestamps
    end

    add_index :flows, [:account_id, :trigger_type, :active]
  end

  # Published definitions are immutable rows so a session that started before a republish
  # keeps walking the graph it was admitted to.
  def create_flow_versions
    create_table :flow_versions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :flow, null: false, foreign_key: { on_delete: :cascade }
      t.integer :version, null: false
      t.jsonb :definition, null: false, default: {}

      t.timestamps
    end

    add_index :flow_versions, [:flow_id, :version], unique: true
    add_foreign_key :flows, :flow_versions, column: :published_version_id, on_delete: :nullify
  end

  def create_flow_sessions
    create_table :flow_sessions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :flow, null: false, foreign_key: { on_delete: :cascade }
      t.references :flow_version, null: false, foreign_key: { on_delete: :cascade }
      t.integer :status, null: false, default: 0
      t.string :current_node_id
      # Watermark, not an association: the message that asked the pending question. Replies
      # at or before it predate the question and are not answers to it.
      t.bigint :awaiting_message_id
      t.jsonb :variables, null: false, default: {}
      # Deadline for a delay node or a question's timeout. Doubles as the claim token: whoever
      # nulls it first, the visitor's reply or the sweep, owns the next step.
      t.datetime :resume_at
      t.datetime :ended_at

      t.timestamps
    end

    # One live session per conversation. This index is the authority behind the router's
    # exclusivity check, so concurrent messages cannot open a second session.
    add_index :flow_sessions, :conversation_id, unique: true, where: 'status = 0',
                                                name: 'index_flow_sessions_on_active_conversation'
    # The sweep only ever looks for live sessions carrying a deadline.
    add_index :flow_sessions, :resume_at, where: 'status = 0 AND resume_at IS NOT NULL',
                                          name: 'index_flow_sessions_on_due_resume_at'
  end

  # Append-only trace of every node a session entered. Without it a misbehaving flow is
  # only visible as the messages it happened to send.
  def create_flow_session_steps
    create_table :flow_session_steps do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :flow_session, null: false, foreign_key: { on_delete: :cascade }
      t.string :node_id, null: false
      t.string :node_type, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :flow_session_steps, [:flow_session_id, :created_at]
  end
end
