class AddOrganizationIdToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :organization_id, :string
  end
end
