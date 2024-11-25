class CreateEventTriggers < ActiveRecord::Migration[5.2]
  def change
    create_table :event_triggers do |t|
      t.string :event_id
      t.string :trigger_id
      t.integer :offset_time
      t.string :offset_duration

      t.timestamps
    end
  end
end
