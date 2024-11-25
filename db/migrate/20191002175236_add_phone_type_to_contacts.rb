class AddPhoneTypeToContacts < ActiveRecord::Migration[5.0]
  def change
    add_column :contacts, :phone_type, :string
  end
end
