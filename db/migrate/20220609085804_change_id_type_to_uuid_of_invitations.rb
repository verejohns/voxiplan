class ChangeIdTypeToUuidOfInvitations < ActiveRecord::Migration[5.2]
  def change
    add_column :invitations, :uuid, :uuid, default: "gen_random_uuid()", null: false

    change_table :invitations do |t|
      t.remove :id
      t.rename :uuid, :id
    end
    execute "ALTER TABLE invitations ADD PRIMARY KEY (id);"
  end
end
