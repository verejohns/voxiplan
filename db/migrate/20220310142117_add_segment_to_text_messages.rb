class AddSegmentToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :segment, :integer
  end
end
