class AddServiceIdToReminder < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :service_id, :integer
  end
end
