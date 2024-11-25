class CreateAnalytics < ActiveRecord::Migration[5.0]
  def change
    create_table :analytics do |t|
      t.datetime :click_time
      t.string :click_device
      t.string :click_Browser
      t.string :click_Language
      t.string :click_geo_location
      t.integer :analysable_id
      t.string :analysable_type

      t.timestamps
    end
    add_index :analytics, [:analysable_type, :analysable_id]
  end
end
