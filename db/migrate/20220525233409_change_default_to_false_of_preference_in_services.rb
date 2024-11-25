class ChangeDefaultToFalseOfPreferenceInServices < ActiveRecord::Migration[5.2]
  def change
    change_column_default :services, :preference, {"pre_confirmation"=>"false", "enabled"=>"false", "widget_enabled"=>"false", "phone_assistant_enabled"=>"false", "chat_enabled"=>"false", "sms_enabled"=>"false", "ai_phone_assistant_enabled"=>"false"}
  end
end
