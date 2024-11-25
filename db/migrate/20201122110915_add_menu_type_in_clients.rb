class AddMenuTypeInClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :menu_type, :string
  end
end
