class RemoveChargebeeSubscriptionPriceFromClients < ActiveRecord::Migration[5.2]
  def change
    remove_column :clients, :chargebee_subscription_price, :decimal
  end
end
