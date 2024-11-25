class AddServiceIdToVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :voxi_sessions, :service_id, :integer
  end
end
