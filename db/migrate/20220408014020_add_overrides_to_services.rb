class AddOverridesToServices < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :overrides, :json, default: nil
  end
end
