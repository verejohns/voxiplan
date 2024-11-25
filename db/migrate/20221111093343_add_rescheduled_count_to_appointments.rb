class AddRescheduledCountToAppointments < ActiveRecord::Migration[5.2]
  def change
    add_column :appointments, :rescheduled_count, :integer
  end
end
