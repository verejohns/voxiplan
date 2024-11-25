class AddClientIdToCustomers < ActiveRecord::Migration[5.0]
  def change
    add_reference :customers, :client, foreign_key: true
  end
end
