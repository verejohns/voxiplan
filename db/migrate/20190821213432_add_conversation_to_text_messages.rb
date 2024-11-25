class AddConversationToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_reference :text_messages, :conversation, foreign_key: true
  end
end
