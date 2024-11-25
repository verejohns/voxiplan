class AddRecordingAndMsgsCountToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :recordings_count, :integer
    add_column :calls, :text_messages_count, :integer
  end
end
