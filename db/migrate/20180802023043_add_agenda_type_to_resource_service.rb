class AddAgendaTypeToResourceService < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :agenda_type, :string
    add_column :resources, :agenda_type, :string
  end
end
