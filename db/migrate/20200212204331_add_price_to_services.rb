class AddPriceToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :price, :float
  end
end
