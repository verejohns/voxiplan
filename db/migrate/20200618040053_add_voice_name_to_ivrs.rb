class AddVoiceNameToIvrs < ActiveRecord::Migration[5.0]
  def change
    add_column :ivrs, :voice_name, :string
  end
end
