class AddMarginToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :margin, :decimal, precision: 5, scale: 2
  end
end
