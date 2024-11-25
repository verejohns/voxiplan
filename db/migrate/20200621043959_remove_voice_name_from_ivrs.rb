class RemoveVoiceNameFromIvrs < ActiveRecord::Migration[5.0]
  def change
    remove_column :ivrs, :voice_name, :string
  end
end
