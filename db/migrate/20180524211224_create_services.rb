class CreateServices < ActiveRecord::Migration[5.0]
  def change
    create_table :services do |t|
      t.belongs_to :ivr, foreign_key: true
      t.string :eid
      t.string :ename
      t.string :name
      t.boolean :enabled

      t.timestamps
    end
    add_index :services, :eid
  end
end
