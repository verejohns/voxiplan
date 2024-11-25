class AddCalendarAccountToAgendaApps < ActiveRecord::Migration[5.2]
  def change
    add_column :agenda_apps, :calendar_account, :string
  end
end
