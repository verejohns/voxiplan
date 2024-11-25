class AddNumOfActiveUsersToPlans < ActiveRecord::Migration[5.0]
  def change
    add_column :plans, :num_of_active_users, :integer
  end
end
