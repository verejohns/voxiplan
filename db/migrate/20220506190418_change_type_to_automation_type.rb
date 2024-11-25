class ChangeTypeToAutomationType < ActiveRecord::Migration[5.2]
  def change
    rename_column :service_notifications, :type, :automation_type
  end
end
