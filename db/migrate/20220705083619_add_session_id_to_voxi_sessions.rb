class AddSessionIdToVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :voxi_sessions, :session_id, :string
  end
end
