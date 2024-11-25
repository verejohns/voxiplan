class AddEmailSubjectHostToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :email_subject_host, :string
  end
end
