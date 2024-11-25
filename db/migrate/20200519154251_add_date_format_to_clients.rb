class AddDateFormatToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :date_format, :string
  end
end
