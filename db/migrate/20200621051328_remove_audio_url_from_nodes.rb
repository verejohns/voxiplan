class RemoveAudioUrlFromNodes < ActiveRecord::Migration[5.0]
  def change
    remove_column :nodes, :audio_url, :string
  end
end
