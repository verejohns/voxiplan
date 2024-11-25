class AddAgendaIdToService < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :agenda_id, :integer
    add_column :services, :is_local, :boolean
    add_column :resources, :agenda_id, :integer
    add_column :resources, :is_local, :boolean
  end
end
