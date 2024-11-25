class AddEnableCalendarToInvitations < ActiveRecord::Migration[5.2]
  def change
    add_column :invitations, :enable_calendar, :boolean
  end
end
