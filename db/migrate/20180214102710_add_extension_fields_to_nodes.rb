class AddExtensionFieldsToNodes < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :ext_prefix, :string
    add_column :nodes, :ext_title, :string
    add_column :nodes, :ext_action, :string
  end
end
