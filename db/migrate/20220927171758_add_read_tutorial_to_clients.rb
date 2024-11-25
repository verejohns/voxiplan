class AddReadTutorialToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :read_tutorial, :bool, default: false
  end
end
