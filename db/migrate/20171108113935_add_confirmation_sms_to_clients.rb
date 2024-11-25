class AddConfirmationSMSToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :confirmation_sms, :boolean, default: false
  end
end
