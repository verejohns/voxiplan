class AddCurrencyCodeToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :currency_code, :string, default: "USD"
  end
end
