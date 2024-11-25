class CreateVoxiSessions < ActiveRecord::Migration[5.0]
  def change
    create_table :voxi_sessions do |t|
      t.string :platform
      t.text :data
      t.belongs_to :ivr, foreign_key: true
      t.belongs_to :client, foreign_key: true
      t.belongs_to :call, foreign_key: true

      t.timestamps
    end
  end
end
