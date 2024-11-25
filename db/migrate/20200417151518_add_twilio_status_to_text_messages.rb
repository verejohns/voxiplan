class AddTwilioStatusToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_column :text_messages, :twilio_status, :string
  end
end
