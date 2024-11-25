class AddGoogleVoiceLocaleToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :google_voice_locale, :string, default: ""
  end
end
