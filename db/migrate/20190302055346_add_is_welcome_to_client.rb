class AddIsWelcomeToClient < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :is_welcomed, :boolean
  end
end
