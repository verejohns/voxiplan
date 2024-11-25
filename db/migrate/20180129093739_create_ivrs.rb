class CreateIvrs < ActiveRecord::Migration[5.0]
  def change
    create_table :ivrs do |t|
      t.string :name
      t.references :client, foreign_key: true
      t.belongs_to :start_node, foreign_key: {to_table: :nodes}

      t.timestamps
    end
  end
end
