class AddExceptionalNumberToContacts < ActiveRecord::Migration[5.0]
  def change
    add_column :contacts, :exceptional_number, :boolean
  end
end
