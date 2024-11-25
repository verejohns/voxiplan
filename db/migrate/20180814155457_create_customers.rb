class CreateCustomers < ActiveRecord::Migration[5.0]
  def change
    create_table :customers do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :gender
      t.string :birthday
      t.string :city
      t.string :street
      t.integer :zipcode
      t.string :phone_country
      t.string :phone_number
      t.string :eid

      t.timestamps
    end
  end
end
