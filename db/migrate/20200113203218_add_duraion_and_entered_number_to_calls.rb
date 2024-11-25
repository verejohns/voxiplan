class AddDuraionAndEnteredNumberToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :duration, :integer
    add_column :calls, :entered_number, :string
  end
end
