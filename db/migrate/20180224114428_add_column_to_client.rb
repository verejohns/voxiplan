class AddColumnToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :appointments_be_suggested, :string
  end
end
