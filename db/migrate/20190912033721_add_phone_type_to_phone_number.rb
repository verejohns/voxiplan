class AddPhoneTypeToPhoneNumber < ActiveRecord::Migration[5.0]
  def change
    add_column :phone_numbers, :phone_type, :string
  end
end
