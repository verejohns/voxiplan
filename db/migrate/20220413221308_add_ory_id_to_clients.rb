class AddOryIdToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :ory_id, :string
  end
end
