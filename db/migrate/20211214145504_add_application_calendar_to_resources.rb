class AddApplicationCalendarToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :application_calendar_id, :string
    add_column :resources, :application_access_token, :string
    add_column :resources, :application_refresh_token, :string
    add_column :resources, :application_sub, :string
  end
end
