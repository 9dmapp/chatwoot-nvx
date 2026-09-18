# The reasons a chat session can be closed for - "payment error", "bug", and so on.
#
# Deliberately not Chatwoot's conversation labels: those live on the conversation, and the
# live-chat widget reuses a visitor's conversation forever, so a label applied on one visit is
# still there on the next one and an agent has to remember to clear it. These are picked per
# session and recorded against that session alone.
class CreateSessionLabels < ActiveRecord::Migration[7.2]
  def change
    create_table :session_labels do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :title, null: false
      t.string :description
      # Archived rather than deleted: past sessions still point at it, and a report of what
      # last quarter was about must not lose its categories because the list was tidied up.
      t.datetime :archived_at

      t.timestamps
    end

    add_index :session_labels, [:account_id, :title], unique: true
    add_index :session_labels, [:account_id, :archived_at]
  end
end
