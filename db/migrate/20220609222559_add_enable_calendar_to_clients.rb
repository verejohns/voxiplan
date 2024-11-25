class AddEnableCalendarToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :enable_calendar, :boolean
  end
end
