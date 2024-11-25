class AddAddressColumnToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :billing_add_1, :string
    add_column :clients, :billing_add_2, :string
    add_column :clients, :billing_city, :string
    add_column :clients, :billing_state, :string
    add_column :clients, :billing_zip, :integer
    add_column :clients, :billing_country, :string
  end
end
