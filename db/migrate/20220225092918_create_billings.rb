class CreateBillings < ActiveRecord::Migration[5.2]
  def change
    create_table :billings do |t|
      t.references :client, foreign_key: true
      t.string :category
      t.string :phone_type
      t.decimal :cost_price, precision: 10, scale: 5
      t.string :cost_price_unit
      t.decimal :profit_margin, precision: 5, scale: 2
      t.decimal :selling_price, precision: 10, scale: 5
      t.string :selling_price_unit
      t.decimal :selling_price_eur, precision: 10, scale: 5

      t.timestamps
    end
  end
end
