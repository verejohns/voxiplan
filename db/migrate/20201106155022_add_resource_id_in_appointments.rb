class AddResourceIdInAppointments < ActiveRecord::Migration[5.0]
  def change
    add_column :appointments, :resource_id, :integer
    add_column :appointments, :service_id, :integer
  end
end
