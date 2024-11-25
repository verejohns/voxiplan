class AddCalendarNameToApplicationCalendars < ActiveRecord::Migration[5.2]
  def change
    add_column :application_calendars, :calendar_name, :string
  end
end
