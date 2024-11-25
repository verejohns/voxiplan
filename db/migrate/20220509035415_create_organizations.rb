class CreateOrganizations < ActiveRecord::Migration[5.2]
  def change
    create_table :organizations do |t|
      t.string :status
      t.string :name
      t.integer :created_by

      t.timestamps
    end
  end
end
