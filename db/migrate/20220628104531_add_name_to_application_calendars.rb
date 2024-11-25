class AddNameToApplicationCalendars < ActiveRecord::Migration[5.2]
  def change
    add_column :application_calendars, :name, :string
  end
end
