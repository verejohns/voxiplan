class AddStartIntervalToServices < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :start_interval, :integer, default: 30
  end
end
