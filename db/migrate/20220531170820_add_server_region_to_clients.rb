class AddServerRegionToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :server_region, :string
  end
end
