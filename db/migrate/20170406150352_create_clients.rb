class CreateClients < ActiveRecord::Migration[5.0]
  def change
    create_table :clients do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.string :schedule_id
      t.string :checksum
      t.json :ivr_text, default: {}

      t.timestamps
    end
  end
end
