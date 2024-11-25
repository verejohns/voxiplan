class AddOtherNameToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :other_name, :string
  end
end
