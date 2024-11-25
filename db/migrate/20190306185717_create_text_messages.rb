class CreateTextMessages < ActiveRecord::Migration[5.0]
  def change
    create_table :text_messages do |t|
      t.string :to
      t.string :content
      t.string :sms_type
      t.references :call, foreign_key: true
      t.string :uuid

      t.timestamps
    end
  end
end
