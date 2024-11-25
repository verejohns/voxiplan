class AddOverridesToNodes < ActiveRecord::Migration[5.2]
  def change
    add_column :nodes, :overrides, :json, default: nil
  end
end
