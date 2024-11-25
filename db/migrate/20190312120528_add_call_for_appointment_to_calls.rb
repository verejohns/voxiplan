class AddCallForAppointmentToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :call_for_appointment, :boolean
  end
end
