class AddBillingCompanyToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :billing_company_name, :string
  end
end
