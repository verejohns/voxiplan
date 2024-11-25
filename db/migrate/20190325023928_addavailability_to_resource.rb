class AddavailabilityToResource < ActiveRecord::Migration[5.0]
  def change
    add_column :resources, :availability, :json, default: BusinessHours::DEFAULT_AVAILABILITY
  end
end
