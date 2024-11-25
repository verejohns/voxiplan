class CreateInvitations < ActiveRecord::Migration[5.2]
  def change
    create_table :invitations do |t|
      t.string :status
      t.integer :organization_id
      t.string :to_email

      t.timestamps
    end
  end
end
