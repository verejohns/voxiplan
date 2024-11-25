class AddCalendarIdToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_column :agenda_apps, :calendar_id, :string
  end
end
