class RemoveEnableCalendarFromClients < ActiveRecord::Migration[5.2]
  def change
    remove_column :clients, :enable_calendar, :boolean
  end
end
