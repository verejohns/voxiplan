class AddEventIdInAppointments < ActiveRecord::Migration[5.0]
  def change
    add_column :appointments, :event_id, :string
  end
end
