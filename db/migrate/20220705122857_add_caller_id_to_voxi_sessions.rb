class AddCallerIdToVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :voxi_sessions, :caller_id, :string
  end
end
