class AddCronofyAccountIdToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_column :agenda_apps, :cronofy_account_id, :string
  end
end
