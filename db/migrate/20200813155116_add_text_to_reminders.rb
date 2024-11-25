class AddTextToReminders < ActiveRecord::Migration[5.0]
  def change
    add_column :reminders, :text, :string
  end
end
