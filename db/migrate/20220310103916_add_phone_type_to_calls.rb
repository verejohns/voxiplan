class AddPhoneTypeToCalls < ActiveRecord::Migration[5.2]
  def change
    add_column :calls, :phone_type, :string
  end
end
