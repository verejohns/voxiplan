class AddIdentifierToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :identifier, :string
  end
end
