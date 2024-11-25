class CreatePaymentDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :payment_details do |t|
      t.string :customer_id
      t.string :subscription_id
      t.string :payment_via
      t.integer :client_id
      t.string :mandate
      t.timestamps
    end
  end
end
