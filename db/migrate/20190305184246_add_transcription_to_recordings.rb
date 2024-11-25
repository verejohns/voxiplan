class AddTranscriptionToRecordings < ActiveRecord::Migration[5.0]
  def change
    add_column :recordings, :transcription, :string
  end
end
