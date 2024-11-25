class AddVoiceToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :voice, :string
    Client.update_all(voice: 'Kate')
  end
end
