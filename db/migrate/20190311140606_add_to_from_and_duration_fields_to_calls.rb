class AddToFromAndDurationFieldsToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :to, :string
    add_column :calls, :from, :string
    add_column :calls, :forwarded_from, :string
    add_column :calls, :finished_at, :datetime
    add_column :calls, :forwarded_at, :datetime
  end
end
