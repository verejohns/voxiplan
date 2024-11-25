class CreatePlans < ActiveRecord::Migration[5.0]
  def change
    create_table :plans do |t|
      t.string :plan_id
      t.string :name
      t.string :amount
      t.string :interval
      t.string :currency
      t.timestamps
    end
  end
end
