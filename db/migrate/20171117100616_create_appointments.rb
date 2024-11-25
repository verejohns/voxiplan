class CreateAppointments < ActiveRecord::Migration[5.0]
  def change
    create_table :appointments do |t|
      t.string :caller_id
      t.string :caller_name
      t.datetime :time
      t.string :tropo_session_id
      t.references :client, foreign_key: true

      t.timestamps
    end
  end
end
