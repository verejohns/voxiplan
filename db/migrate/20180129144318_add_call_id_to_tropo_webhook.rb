class AddCallIdToTropoWebhook < ActiveRecord::Migration[5.0]
  def change
    add_column :tropo_webhooks, :internal_call_id, :integer
    add_index :tropo_webhooks, :internal_call_id
  end
end
