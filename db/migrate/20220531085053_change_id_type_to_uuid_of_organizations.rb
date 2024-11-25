class ChangeIdTypeToUuidOfOrganizations < ActiveRecord::Migration[5.2]
  def change
    add_column :organizations, :uuid, :uuid, default: "gen_random_uuid()", null: false

    change_table :organizations do |t|
      t.remove :id
      t.rename :uuid, :id
    end
    execute "ALTER TABLE organizations ADD PRIMARY KEY (id);"
  end
end
