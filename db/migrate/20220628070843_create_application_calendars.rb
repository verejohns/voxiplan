class CreateApplicationCalendars < ActiveRecord::Migration[5.2]
  def change
    create_table :application_calendars, id: :uuid do |t|
      t.string :organization_id
      t.integer :member_id
      t.string :calendar_id
      t.string :access_token
      t.string :refresh_token
      t.string :application_sub

      t.timestamps
    end
  end
end
