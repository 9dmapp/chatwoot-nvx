class CreateFlowInboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :flow_inboxes do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.references :flow, null: false, foreign_key: { on_delete: :cascade }
      t.references :inbox, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end

    add_index :flow_inboxes, [:flow_id, :inbox_id], unique: true
  end
end
