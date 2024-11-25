class AddChargebeeSubscriptionPriceToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :chargebee_subscription_price, :decimal, precision: 5, scale: 2
  end
end
