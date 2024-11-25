class AddSessionIdToConversations < ActiveRecord::Migration[5.0]
  def change
    add_column :conversations, :session_id, :string
    add_index :conversations, :session_id
  end
end
