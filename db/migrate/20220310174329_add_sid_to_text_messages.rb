class AddSidToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :sid, :string
  end
end
