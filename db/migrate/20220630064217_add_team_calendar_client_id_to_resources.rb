class AddTeamCalendarClientIdToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :team_calendar_client_id, :integer
  end
end
