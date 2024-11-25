class AddCronofyAccessAndRefreshTokensToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_column :agenda_apps, :cronofy_access_token, :string
    add_column :agenda_apps, :cronofy_refresh_token, :string
  end
end
