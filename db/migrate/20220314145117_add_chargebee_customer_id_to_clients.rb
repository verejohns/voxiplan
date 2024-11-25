class AddChargebeeCustomerIdToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :chargebee_customer_id, :string
  end
end
