class AddCooldownMinutesToFlows < ActiveRecord::Migration[7.1]
  def change
    # How long before the same visitor can enter this flow again. NULL keeps the original
    # behaviour: a visitor is admitted once and never re-greeted.
    add_column :flows, :cooldown_minutes, :integer
  end
end
