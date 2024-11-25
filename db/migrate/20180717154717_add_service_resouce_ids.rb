class AddServiceResouceIds < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :dependent_ids, :string, array: true, default: []
    add_column :services, :service_id, :integer
    add_column :resources, :dependent_ids, :string, array: true, default: []
    add_column :resources, :resource_id, :integer
  end
end
