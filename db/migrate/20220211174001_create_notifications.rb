class CreateNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :notifications do |t|
      t.integer :client_id
      t.string :channel_id
      t.datetime :changes_since
      t.timestamps
    end
  end
end
