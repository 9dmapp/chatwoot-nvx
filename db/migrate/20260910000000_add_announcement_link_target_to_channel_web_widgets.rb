class AddAnnouncementLinkTargetToChannelWebWidgets < ActiveRecord::Migration[7.0]
  def change
    add_column :channel_web_widgets, :announcement_link_target, :string, default: 'new_tab', null: false
  end
end
