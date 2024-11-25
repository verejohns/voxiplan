class AddSMSTextToReminders < ActiveRecord::Migration[5.0]
  def change
    add_column :reminders, :sms_text, :string
  end
end
