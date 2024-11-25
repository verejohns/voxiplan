class AddCountryToCustomers < ActiveRecord::Migration[5.0]
  def change
    add_column :customers, :country, :string
  end
end
