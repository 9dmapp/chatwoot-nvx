class AddAnnouncementToChannelWebWidgets < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_web_widgets, :announcement, :string
    add_column :channel_web_widgets, :announcement_url, :string
  end
end
