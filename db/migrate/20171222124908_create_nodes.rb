class CreateNodes < ActiveRecord::Migration[5.0]
  def change
    create_table :nodes do |t|
      t.string :name, index: true
      t.string :type
      t.string :next
      t.text :text
      t.string :voice
      t.integer :timeout
      t.integer :tries
      t.boolean :required
      t.boolean :interruptible
      t.string :timeout_next
      t.string :invalid_next
      t.json :choices

      t.timestamps
    end
  end
end
