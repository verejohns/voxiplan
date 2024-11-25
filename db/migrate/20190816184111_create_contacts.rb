class CreateContacts < ActiveRecord::Migration[5.0]
  def change
    create_table :contacts do |t|
      t.integer :customer_id
      t.string :phone
      t.string :country

      t.timestamps
    end
  end
end
