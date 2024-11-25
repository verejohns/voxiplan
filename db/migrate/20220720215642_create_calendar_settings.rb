class CreateCalendarSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :calendar_settings do |t|
      t.references :client, foreign_key: true
      t.string :slot_duration, default: '00:30:00'
      t.string :snap_duration, default: '00:30:00'
      t.string :min_time, default: '00:00:00'
      t.string :max_time, default: '24:00:00'
      t.string :hidden_days, default: '0,6'
      t.string :first_day, default: '1'
      t.string :time_format, default: '12'
      t.json :availabilities, default: BusinessHours::DEFAULT_AVAILABILITY
      t.timestamps
    end
  end
end
