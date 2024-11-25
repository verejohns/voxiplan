class CreateUsers < ActiveRecord::Migration[5.0]
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.string :number
      t.string :sip
      t.string :sip_login
      t.string :sip_pwd
      t.string :sip_host
      t.references :client, foreign_key: true

      t.timestamps
    end
  end
end
