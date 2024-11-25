class CreateTestIdentifiers < ActiveRecord::Migration[5.0]
  def change
    create_table :test_identifiers do |t|
      t.string :identifier
      t.string :country_code

      t.timestamps
    end
  end
end
