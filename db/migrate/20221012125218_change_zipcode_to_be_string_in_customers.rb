class ChangeZipcodeToBeStringInCustomers < ActiveRecord::Migration[5.2]
  def change
    change_column :customers, :zipcode, :string
  end
end
