class AddSourceToAppointments < ActiveRecord::Migration[5.0]
  def change
    add_column :appointments, :source, :string
    add_column :appointments, :ivr_id, :integer
  end
end
