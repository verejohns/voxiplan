class AddEmailSubjectToNode < ActiveRecord::Migration[5.0]
  def change
    add_column :nodes, :email_subject, :json, default: {}
  end
end
