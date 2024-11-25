class AddOverridesToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :overrides, :json, default: nil
  end
end
