class AddAudioUrlToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :audio_url, :string
  end
end
