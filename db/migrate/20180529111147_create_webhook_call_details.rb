class CreateWebhookCallDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :webhook_call_details do |t|
      t.string :email
      t.text :access_token
      t.json :auth_data
      t.references :client

      t.timestamps
    end
  end
end
