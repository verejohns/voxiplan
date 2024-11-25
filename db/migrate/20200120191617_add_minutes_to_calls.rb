class AddMinutesToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :minutes, :integer
  end
end
