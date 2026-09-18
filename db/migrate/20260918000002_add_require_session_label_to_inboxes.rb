# Lets an inbox insist that an agent says what a session was about before closing it.
#
# Per inbox rather than per account because only the inboxes a human works belong under this
# rule; an API inbox whose conversations are resolved by an integration has no agent to ask.
class AddRequireSessionLabelToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :require_session_label, :boolean, null: false, default: false
  end
end
