class AddConditionToNode < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :condition, :string
    add_column :nodes, :left_operand, :string
    add_column :nodes, :right_operand, :json, default: []
  end
end
