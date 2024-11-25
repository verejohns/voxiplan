class AddCreatedOnAgendaToCustomer < ActiveRecord::Migration[5.0]
  def change
    add_column :customers, :created_on_agenda, :boolean
  end
end
