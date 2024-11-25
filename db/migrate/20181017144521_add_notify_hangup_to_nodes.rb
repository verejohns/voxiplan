class AddNotifyHangupToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :notify_hangup, :boolean, default: true
  end
end
