class SetDefaultDurationToServices < ActiveRecord::Migration[5.0]
  def change
    change_column :services, :duration, :integer, default: 30
  end
end
