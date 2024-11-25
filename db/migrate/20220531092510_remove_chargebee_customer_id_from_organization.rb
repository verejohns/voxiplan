class RemoveChargebeeCustomerIdFromOrganization < ActiveRecord::Migration[5.2]
  def change
    remove_column :organizations, :chargebee_customer_id, :string
  end
end
