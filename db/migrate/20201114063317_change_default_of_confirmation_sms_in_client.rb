class ChangeDefaultOfConfirmationSMSInClient < ActiveRecord::Migration[5.0]
  def change
    change_column_default :clients, :confirmation_sms, true
  end
end
