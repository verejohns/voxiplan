class AddConflictCalendarsToApplicationCalendars < ActiveRecord::Migration[5.2]
  def change
    add_column :application_calendars, :conflict_calendars, :string
  end
end
