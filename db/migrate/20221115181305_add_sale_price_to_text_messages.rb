class AddSalePriceToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :sale_price, :decimal, precision: 5, scale: 2
  end
end
