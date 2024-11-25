class AddUidToUsersClientsAndIvrs < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :uid, :string
    add_index :users, :uid, unique: true

    add_column :clients, :uid, :string
    add_index :clients, :uid, unique: true

    add_column :ivrs, :uid, :string
    add_index :ivrs, :uid, unique: true
  end
end
