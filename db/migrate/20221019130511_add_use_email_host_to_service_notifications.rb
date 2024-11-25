class AddUseEmailHostToServiceNotifications < ActiveRecord::Migration[5.2]
  def change
    add_column :service_notifications, :use_email_host, :boolean
  end
end
