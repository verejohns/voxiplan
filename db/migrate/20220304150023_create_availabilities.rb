class CreateAvailabilities < ActiveRecord::Migration[5.2]
  def change
    create_table :availabilities do |t|
      t.references :schedule_template, foreign_key: true
      t.json :availabilities, default: BusinessHours::DEFAULT_AVAILABILITY
      t.json :overrides, default: nil
      t.timestamps
    end
  end
end
