class AddCountryCodeToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :country_code, :string
  end
end
