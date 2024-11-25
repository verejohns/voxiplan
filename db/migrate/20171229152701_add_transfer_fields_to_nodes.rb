class AddTransferFieldsToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :to, :string
    add_column :nodes, :from, :string
  end
end
