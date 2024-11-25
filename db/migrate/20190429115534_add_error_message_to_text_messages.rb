class AddErrorMessageToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :text_messages, :error_message, :string
  end
end
