class AddOrganizationIdToAgendaApps < ActiveRecord::Migration[5.2]
  def change
    add_column :agenda_apps, :organization_id, :string
  end
end
