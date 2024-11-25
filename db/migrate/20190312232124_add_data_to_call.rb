class AddDataToCall < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :data, :json, default: {}
  end
end
