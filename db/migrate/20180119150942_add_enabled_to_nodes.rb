class AddEnabledToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :enabled, :boolean, default: true
    add_column :nodes, :can_enable, :boolean, default: false
  end
end
