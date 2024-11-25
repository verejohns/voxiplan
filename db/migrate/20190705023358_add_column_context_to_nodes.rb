class AddColumnContextToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :context, :json
  end
end
