class CreateTropoWebhooks < ActiveRecord::Migration[5.0]
  def change
    create_table :tropo_webhooks do |t|
      t.string :resource
      t.string :name
      t.string :payload_id
      t.string :event
      t.string :call_id
      t.string :reason
      t.string :application_type
      t.integer :message_count
      t.string :parent_call_id
      t.string :parent_session_id
      t.string :session_id
      t.string :network
      t.datetime :initiation_time
      t.integer :duration
      t.string :account_id
      t.string :start_url
      t.string :from
      t.string :to
      t.datetime :start_time
      t.datetime :end_time
      t.string :application_id
      t.string :application_name
      t.string :direction
      t.string :status
      t.json :raw

      t.timestamps
    end
  end
end
