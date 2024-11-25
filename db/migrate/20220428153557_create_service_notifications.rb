class CreateServiceNotifications < ActiveRecord::Migration[5.2]
  def change
    create_table :service_notifications do |t|
      t.references :client, foreign_key: true
      t.references :service, foreign_key: true
      t.string :type
      t.string :subject
      t.json :text, default: nil
      t.timestamps
    end
  end
end
