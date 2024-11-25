class AddApiFieldsToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :method_name, :string
    add_column :nodes, :parameters, :json
    add_column :nodes, :results, :json
  end
end
