class AddSalePriceToCalls < ActiveRecord::Migration[5.2]
  def change
    add_column :calls, :sale_price, :decimal, precision: 5, scale: 2
  end
end
