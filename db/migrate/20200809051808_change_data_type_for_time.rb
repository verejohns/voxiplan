class ChangeDataTypeForTime < ActiveRecord::Migration[5.0]
  def change
    change_column(:reminders, :time, :string)
  end
end
