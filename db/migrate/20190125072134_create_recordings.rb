class CreateRecordings < ActiveRecord::Migration[5.0]
  def change
    create_table :recordings do |t|
      t.string :file_name
      t.string :url
      t.belongs_to :call, foreign_key: true
      t.string :eid
      t.string :duration
      t.string :status
      t.string :started_at
      t.string :uuid

      t.timestamps
    end
  end
end
