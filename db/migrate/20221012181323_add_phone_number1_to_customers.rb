class AddPhoneNumber1ToCustomers < ActiveRecord::Migration[5.2]
  def change
    add_column :customers, :phone_number1, :string
    add_column :customers, :phone_number2, :string
    add_column :customers, :phone_number3, :string
  end
end
