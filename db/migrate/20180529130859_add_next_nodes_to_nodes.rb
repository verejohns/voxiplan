class AddNextNodesToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :next_nodes, :json
  end
end
