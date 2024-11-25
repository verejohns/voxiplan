class AddPhoneCountry1ToCustomers < ActiveRecord::Migration[5.2]
  def change
    add_column :customers, :phone_country1, :string
    add_column :customers, :phone_country2, :string
    add_column :customers, :phone_country3, :string
  end
end
