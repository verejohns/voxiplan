class AddDefaultParamsToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :default_params, :text
  end
end
