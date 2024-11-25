class AddGatherNumberFieldsToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :input_min_length, :integer
    add_column :nodes, :input_max_length, :integer
    add_column :nodes, :input_terminator, :string
  end
end
