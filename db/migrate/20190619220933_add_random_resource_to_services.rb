class AddRandomResourceToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :random_resource, :boolean, default: :true
  end
end
