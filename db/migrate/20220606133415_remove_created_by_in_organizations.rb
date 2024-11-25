class RemoveCreatedByInOrganizations < ActiveRecord::Migration[5.2]
  def change
    remove_column :organizations, :created_by, :integer
  end
end
