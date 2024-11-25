class AddIsIncludeAgendaToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :is_include_agenda, :bool, default: false
  end
end
