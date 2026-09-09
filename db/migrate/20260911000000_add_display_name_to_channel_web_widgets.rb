class AddDisplayNameToChannelWebWidgets < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_web_widgets, :display_name, :string
  end
end
