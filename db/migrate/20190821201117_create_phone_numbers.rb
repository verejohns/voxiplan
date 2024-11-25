class CreatePhoneNumbers < ActiveRecord::Migration[5.0]
  def change
    create_table :phone_numbers do |t|
      t.string :number
      t.string :friendly_name
      t.boolean :sms
      t.boolean :voice
      t.belongs_to :client, foreign_key: true

      t.timestamps
    end
  end
end
