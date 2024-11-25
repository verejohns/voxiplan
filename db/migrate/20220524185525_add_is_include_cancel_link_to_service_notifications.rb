class AddIsIncludeCancelLinkToServiceNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :service_notifications, :is_include_cancel_link, :bool
  end
end
