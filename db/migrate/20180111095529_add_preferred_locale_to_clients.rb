class AddPreferredLocaleToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :preferred_locale, :string
  end
end
