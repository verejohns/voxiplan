class DropApplicationCalendarTable < ActiveRecord::Migration[5.2]
  def change
    drop_table :application_calendars
  end
end
