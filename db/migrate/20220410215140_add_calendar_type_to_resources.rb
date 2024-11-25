class AddCalendarTypeToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :calendar_type, :string, default: 'app_calendar'
    add_column :resources, :my_calendar_type, :string, default: 'default'
  end
end
