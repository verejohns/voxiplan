class AddTimoutAndInvalidForTry1 < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :try1_invalid, :string
    add_column :nodes, :try1_timeout, :string
  end
end
