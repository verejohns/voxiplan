class AddEventIdToSubscriptions < ActiveRecord::Migration[5.2]
  def change
    add_column :subscriptions, :event_id, :string
    add_column :subscriptions, :membership, :string
    add_column :subscriptions, :period, :string
    add_column :subscriptions, :seats, :integer
    add_column :subscriptions, :amount, :integer
  end
end
