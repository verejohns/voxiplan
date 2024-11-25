class CreateIdentifiers < ActiveRecord::Migration[5.0]
  def change
    create_table :identifiers do |t|
      t.string :identifier
      t.belongs_to :ivr, foreign_key: true

      t.timestamps
    end
  end
end
