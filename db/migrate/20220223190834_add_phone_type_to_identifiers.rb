class AddPhoneTypeToIdentifiers < ActiveRecord::Migration[5.2]
  def change
    add_column :identifiers, :phone_type, :string
  end
end
