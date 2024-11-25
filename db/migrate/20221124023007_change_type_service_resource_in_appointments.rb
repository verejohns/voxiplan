class ChangeTypeServiceResourceInAppointments < ActiveRecord::Migration[5.2]
  def change
    change_column :appointments, :service_id, :string
    change_column :appointments, :resource_id, :string
  end
end
