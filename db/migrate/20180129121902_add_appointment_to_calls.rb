class AddAppointmentToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :appointment_time, :datetime
  end
end
