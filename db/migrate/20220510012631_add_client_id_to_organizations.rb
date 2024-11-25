class AddClientIdToOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :client_id, :integer
  end
end
