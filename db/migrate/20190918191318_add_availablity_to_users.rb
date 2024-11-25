class AddAvailablityToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :availability, :json, default: BusinessHours::DEFAULT_AVAILABILITY
  end
end
