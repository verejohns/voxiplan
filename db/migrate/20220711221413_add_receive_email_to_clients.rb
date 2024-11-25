class AddReceiveEmailToClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :receive_email, :bool, default: true
  end
end
