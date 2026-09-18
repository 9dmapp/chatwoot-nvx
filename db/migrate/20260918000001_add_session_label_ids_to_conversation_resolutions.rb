# Records which session labels an agent chose when closing the session.
#
# Replaces the `labels` column, which snapshotted whatever conversation labels happened to be on
# the conversation at the time. That answered a different question: it described the conversation,
# not the visit, and still left the agent maintaining a label list across visits.
class AddSessionLabelIdsToConversationResolutions < ActiveRecord::Migration[7.2]
  def change
    add_column :conversation_resolutions, :session_label_ids, :bigint, array: true, null: false, default: []
    add_index :conversation_resolutions, :session_label_ids, using: :gin

    remove_column :conversation_resolutions, :labels, :string, array: true, null: false, default: []
  end
end
