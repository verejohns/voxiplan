class AddBilllingDetailsToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :billing_first_name, :string
    add_column :clients, :billing_last_name, :string
    add_column :clients, :tax_id, :string
    add_column :clients, :customer_type, :string
  end
end
