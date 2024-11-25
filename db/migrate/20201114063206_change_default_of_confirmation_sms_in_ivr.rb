class ChangeDefaultOfConfirmationSMSInIvr < ActiveRecord::Migration[5.0]
  def change
    change_column_default :ivrs, :confirmation_sms, true
  end
end
