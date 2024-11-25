class ChangeTypeServiceResourceInVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    change_column :voxi_sessions, :service_id, :string
    change_column :voxi_sessions, :resource_id, :string
  end
end
