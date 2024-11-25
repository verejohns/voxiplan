class AddDetailsToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :address_one, :string
    add_column :clients, :address_two, :string
    add_column :clients, :city, :string
    add_column :clients, :state, :string
    add_column :clients, :zip, :string
    add_column :clients, :language, :string
  end
end
