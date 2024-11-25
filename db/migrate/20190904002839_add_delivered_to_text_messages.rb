class AddDeliveredToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :text_messages, :delivered, :boolean
  end
end
