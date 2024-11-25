class AddIsTwilioToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :is_twilio, :bool
  end
end
