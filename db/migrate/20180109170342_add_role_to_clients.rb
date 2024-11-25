class AddRoleToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :role, :integer
  end
end
