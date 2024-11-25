class AddCronofyProfileToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_column :agenda_apps, :cronofy_profile_id, :string
    add_column :agenda_apps, :cronofy_provider_name, :string
    add_column :agenda_apps, :cronofy_profile_name, :string
  end
end
