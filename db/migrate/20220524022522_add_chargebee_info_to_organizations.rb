class AddChargebeeInfoToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :chargebee_customer_id, :string
    add_column :organizations, :chargebee_subscription_id, :string
    add_column :organizations, :chargebee_subscription_plan, :string
    add_column :organizations, :chargebee_seats, :integer
    add_column :organizations, :chargebee_subscription_period, :string
  end
end
