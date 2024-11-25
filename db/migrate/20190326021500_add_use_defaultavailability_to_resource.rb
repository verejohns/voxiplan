class AddUseDefaultavailabilityToResource < ActiveRecord::Migration[5.0]
  def change
    add_column :resources, :use_default_availability, :boolean, default: true
  end
end
