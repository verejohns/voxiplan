class AddIsUserAccountToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :is_user_account, :bool
  end
end
