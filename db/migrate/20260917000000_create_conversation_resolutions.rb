# One row per time a conversation is resolved, holding the labels it carried at that moment.
#
# Labels live on the conversation, and the live-chat widget reuses a visitor's conversation
# forever, so a visitor who comes back three times with three different problems ends up with one
# row carrying all three labels and no record of which visit earned which. Freezing the labels at
# each resolution is what makes "how many chats were about payments this month" answerable without
# taking the visitor's history away from them.
class CreateConversationResolutions < ActiveRecord::Migration[7.2]
  def change
    create_table :conversation_resolutions do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.bigint :inbox_id, null: false
      t.bigint :assignee_id
      # Snapshot rather than a join to labels: a label that is later renamed or deleted must not
      # rewrite what past resolutions were about.
      t.string :labels, array: true, null: false, default: []
      t.datetime :resolved_at, null: false

      t.timestamps
    end

    # The report always scopes to an account and a date range.
    add_index :conversation_resolutions, [:account_id, :resolved_at]
    add_index :conversation_resolutions, [:account_id, :inbox_id, :resolved_at]
    add_index :conversation_resolutions, :labels, using: :gin
  end
end
