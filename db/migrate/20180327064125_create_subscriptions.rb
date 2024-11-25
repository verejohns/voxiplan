class CreateSubscriptions < ActiveRecord::Migration[5.0]
  def change
    create_table :subscriptions do |t|
      t.string :subscription_id
      t.string :plan_id, array: true, default: []
      t.string :client_id
      t.timestamps
    end
  end
end
