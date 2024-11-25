class AddReminderSubjectInReminders < ActiveRecord::Migration[5.0]
  def change
    add_column :reminders, :reminder_subject, :string
  end
end
