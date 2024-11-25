class AddMarginToCalls < ActiveRecord::Migration[5.2]
  def change
    add_column :calls, :margin, :decimal, precision: 5, scale: 2
  end
end
