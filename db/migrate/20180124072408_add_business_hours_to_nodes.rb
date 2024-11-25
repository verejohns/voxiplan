class AddBusinessHoursToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :business_hours, :json, default: {}
  end
end
