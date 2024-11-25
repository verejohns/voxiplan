class AddIncomingFieldsToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :text_messages, :from, :string
    add_column :text_messages, :incoming, :boolean
    add_column :text_messages, :eid, :string
    add_column :text_messages, :time_sent, :datetime
  end
end
