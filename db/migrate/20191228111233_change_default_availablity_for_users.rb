class ChangeDefaultAvailablityForUsers < ActiveRecord::Migration[5.0]
  def change
    change_column_default(
        :users,
        :availability,
        from: BusinessHours::DEFAULT_AVAILABILITY,
        to: BusinessHours::AVAILABLE_24H,
    )
  end
end
