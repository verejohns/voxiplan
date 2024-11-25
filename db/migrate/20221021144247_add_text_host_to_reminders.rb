class AddTextHostToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :text_host, :string
  end
end
