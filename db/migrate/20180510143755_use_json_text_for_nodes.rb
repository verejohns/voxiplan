class UseJsonTextForNodes < ActiveRecord::Migration[5.0]
  def up
    # rename_column :nodes, :text, :text_backup
    # add_column :nodes, :text, :json
    # Node.find_each do |node|
    #   # node.text =  node.text_backup if node.text_backup
    #   # node.save
    #   node.update_column(:text, node.text_backup) if node.text_backup
    # end
    # remove_column :nodes, :text_backup

    change_column :nodes, :text, 'json USING to_json("text"::text)'
  end

  def down
    change_column :nodes, :text, :text
  end
end
