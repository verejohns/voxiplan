class AddSipToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :sip, :string
  end
end
