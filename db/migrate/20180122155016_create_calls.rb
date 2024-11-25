class CreateCalls < ActiveRecord::Migration[5.0]
  def change
    create_table :calls do |t|
      t.string :tropo_session_id
      t.string :tropo_call_id
      t.string :caller_id
      t.string :caller_name
      t.references :client, foreign_key: true

      t.timestamps
    end
  end
end
