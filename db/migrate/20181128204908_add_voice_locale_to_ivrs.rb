class AddVoiceLocaleToIvrs < ActiveRecord::Migration[5.0]
  def change
    add_column :ivrs, :voice_locale, :string
  end
end
