class AddTimifyCompanyIdToAgendaApps < ActiveRecord::Migration[5.2]
  def change
    add_column :agenda_apps, :timify_company_id, :string
  end
end
