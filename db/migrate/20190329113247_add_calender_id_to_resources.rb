class AddCalenderIdToResources < ActiveRecord::Migration[5.0]
  def change
    add_column :resources, :calendar_id, :string
  end
end
