class AddAgentNumberToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :agent_number, :string
  end
end
