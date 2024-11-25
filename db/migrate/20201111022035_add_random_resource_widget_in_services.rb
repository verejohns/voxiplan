class AddRandomResourceWidgetInServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :random_resource_widget, :boolean
  end
end
