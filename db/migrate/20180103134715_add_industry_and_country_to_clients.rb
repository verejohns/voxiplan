class AddIndustryAndCountryToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :industry, :string
    add_column :clients, :country, :string
  end
end
