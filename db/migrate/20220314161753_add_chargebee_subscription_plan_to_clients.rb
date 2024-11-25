class AddChargebeeSubscriptionPlanToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :chargebee_subscription_plan, :string, :default=> 'trial'
  end
end
