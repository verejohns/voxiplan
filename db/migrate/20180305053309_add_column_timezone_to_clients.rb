class AddColumnTimezoneToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :time_zone, :string
  end
end
