class ChangeTypeOfCallData < ActiveRecord::Migration[5.0]
  def up
    change_column :calls, :data, :text, default: nil
  end

  def down
  end
end
