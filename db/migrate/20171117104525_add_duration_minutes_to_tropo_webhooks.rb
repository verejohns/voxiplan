class AddDurationMinutesToTropoWebhooks < ActiveRecord::Migration[5.0]
  def change
    add_column :tropo_webhooks, :duration_minutes, :integer
  end
end
