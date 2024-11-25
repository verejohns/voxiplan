class AddCustomerIdToVoxiSessions < ActiveRecord::Migration[5.2]
  def change
    add_column :voxi_sessions, :customer_id, :integer
  end
end
