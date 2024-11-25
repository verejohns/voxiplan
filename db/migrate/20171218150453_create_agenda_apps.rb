class CreateAgendaApps < ActiveRecord::Migration[5.0]
  def change
    create_table :agenda_apps do |t|
      t.string :type
      t.string :ss_schedule_id
      t.string :ss_checksum
      t.text :ss_default_params
      t.string :mm_login
      t.string :mm_pwd
      t.string :mm_kid
      t.references :client, foreign_key: true

      t.timestamps
    end
  end
end
