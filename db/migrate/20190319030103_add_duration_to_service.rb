class AddDurationToService < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :duration, :string
  end
end
