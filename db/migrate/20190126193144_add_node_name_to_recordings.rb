class AddNodeNameToRecordings < ActiveRecord::Migration[5.0]
  def change
    add_column :recordings, :node_name, :string
  end
end
