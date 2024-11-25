class CreateJoinTableNodesUsers < ActiveRecord::Migration[5.0]
  def change
    create_join_table :nodes, :users do |t|
      t.index [:node_id, :user_id], unique: true
       # t.index [:user_id, :node_id]
    end
  end
end
