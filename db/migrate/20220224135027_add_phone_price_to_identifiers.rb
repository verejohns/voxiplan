class AddPhonePriceToIdentifiers < ActiveRecord::Migration[5.2]
  def change
    add_column :identifiers, :phone_price, :decimal, precision: 5, scale: 2
  end
end
