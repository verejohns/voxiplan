class ChangeDefaultValueOfAiLanguageFromIvrs < ActiveRecord::Migration[5.2]
  def change
    change_column_default :ivrs, :message, from: nil, to: 'en-US-Wavenet-C'
    change_column_default :ivrs, :message_locale, from: nil, to: 'en-US'
  end
end
