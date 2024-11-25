class AddTimifyFieldsToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_column :agenda_apps, :timify_email, :string
    add_column :agenda_apps, :timify_access_token, :string
  end
end
