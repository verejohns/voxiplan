class FixColumnNameReminderSubject < ActiveRecord::Migration[5.0]
  def change
    rename_column :reminders, :reminder_subject, :email_subject
  end
end
