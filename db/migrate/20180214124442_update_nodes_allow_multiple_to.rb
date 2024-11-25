class UpdateNodesAllowMultipleTo < ActiveRecord::Migration[5.0]
  def up
    change_column :nodes, :to, 'json USING to_json("to"::text)'
  end
  def down
    change_column :nodes, :to, :string
  end
end
