class AddTimeDurationToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :time_duration, :string, default: 'minutes'
  end
end
