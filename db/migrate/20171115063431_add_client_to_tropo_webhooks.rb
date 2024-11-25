class AddClientToTropoWebhooks < ActiveRecord::Migration[5.0]
  def change
    add_reference :tropo_webhooks, :client, foreign_key: true
  end
end
