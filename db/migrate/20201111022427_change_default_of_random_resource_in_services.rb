class ChangeDefaultOfRandomResourceInServices < ActiveRecord::Migration[5.0]
  def change
    change_column_default :services, :random_resource, false
  end
end
