class AddStatusToTextMessages < ActiveRecord::Migration[5.0]
  def change
    remove_column :text_messages, :delivered
    add_column :text_messages, :status, :integer
  end
end
