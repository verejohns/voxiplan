class AddConflictCalendarsToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :conflict_calendars, :string
  end
end
