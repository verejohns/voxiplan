class RemovePlanIdFromSubscriptions < ActiveRecord::Migration[5.2]
  def change
    remove_column :subscriptions, :plan_id, :string
  end
end
