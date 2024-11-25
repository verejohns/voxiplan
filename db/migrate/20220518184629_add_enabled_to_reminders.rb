class AddEnabledToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :enabled, :bool
  end
end
