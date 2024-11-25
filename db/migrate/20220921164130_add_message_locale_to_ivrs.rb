class AddMessageLocaleToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :message_locale, :string
  end
end
