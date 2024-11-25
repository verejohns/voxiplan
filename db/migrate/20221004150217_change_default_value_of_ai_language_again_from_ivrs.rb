class ChangeDefaultValueOfAiLanguageAgainFromIvrs < ActiveRecord::Migration[5.2]
  def change
    change_column_default :ivrs, :message, from: 'en-US-Wavenet-C', to: 'en-US-Neural2-F'
  end
end
