class AddAttachmentRecordingToCalls < ActiveRecord::Migration[5.0]
  def self.up
    change_table :calls do |t|
      t.attachment :recording
    end
  end

  def self.down
    remove_attachment :calls, :recording
  end
end
