class AddDefaultColumnToResourceAndServices < ActiveRecord::Migration[5.0]
  def change
    add_column :resources, :is_default, :boolean, default: false
    add_column :services, :is_default, :boolean, default: false
  end
end
