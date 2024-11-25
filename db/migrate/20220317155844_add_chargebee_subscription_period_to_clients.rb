class AddChargebeeSubscriptionPeriodToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :chargebee_subscription_period, :string
  end
end
