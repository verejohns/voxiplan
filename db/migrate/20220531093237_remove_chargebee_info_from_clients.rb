class RemoveChargebeeInfoFromClients < ActiveRecord::Migration[5.2]
  def change
    remove_column :clients, :chargebee_customer_id, :string
    remove_column :clients, :chargebee_subscription_id, :string
    remove_column :clients, :chargebee_subscription_plan, :string
    remove_column :clients, :chargebee_seats, :integer
    remove_column :clients, :chargebee_subscription_period, :string
  end
end
