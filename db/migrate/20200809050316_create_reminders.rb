class CreateReminders < ActiveRecord::Migration[5.0]
  def change
    create_table :reminders do |t|
      t.string :advance_time_offset
      t.string :advance_time_duration
      t.datetime :time
      t.boolean :sms
      t.boolean :email
      t.belongs_to :client
      t.belongs_to :ivr

      t.timestamps
    end
  end
end