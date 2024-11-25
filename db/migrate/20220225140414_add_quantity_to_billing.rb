class AddQuantityToBilling < ActiveRecord::Migration[5.2]
  def change
    add_column :billings, :quantity, :integer
  end
end
