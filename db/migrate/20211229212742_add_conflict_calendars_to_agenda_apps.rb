class AddConflictCalendarsToAgendaApps < ActiveRecord::Migration[5.2]
  def change
    add_column :agenda_apps, :conflict_calendars, :string
  end
end
