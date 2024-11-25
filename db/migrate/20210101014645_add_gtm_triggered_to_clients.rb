class AddGtmTriggeredToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :gtm_triggered, :boolean
  end
end
