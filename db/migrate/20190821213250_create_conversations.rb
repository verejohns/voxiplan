class CreateConversations < ActiveRecord::Migration[5.0]
  def change
    create_table :conversations do |t|
      t.references :client, foreign_key: true
      t.references :ivr, foreign_key: true
      t.string :from
      t.string :to
      t.datetime :expire_at

      t.timestamps
    end
  end
end
