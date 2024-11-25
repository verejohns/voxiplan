class AddResourceIdToVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :voxi_sessions, :resource_id, :integer
  end
end
