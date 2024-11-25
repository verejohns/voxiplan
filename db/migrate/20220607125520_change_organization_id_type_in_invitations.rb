class ChangeOrganizationIdTypeInInvitations < ActiveRecord::Migration[5.2]
  def change
    change_column :invitations, :organization_id, :string
  end
end
