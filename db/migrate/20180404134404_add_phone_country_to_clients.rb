class AddPhoneCountryToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :phone_country, :string
  end
end
