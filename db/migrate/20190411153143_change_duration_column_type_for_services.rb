class ChangeDurationColumnTypeForServices < ActiveRecord::Migration[5.0]
  def change
    change_column :services, :duration, "integer USING CAST(duration AS integer)"
  end
end
