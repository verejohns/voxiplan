class ChangeDefaultValueOfCalendarTypeFromResources < ActiveRecord::Migration[5.2]
  def change
    change_column_default :resources, :calendar_type, from: 'app_calendar', to: 'my_calendar'
  end
end
