class AddPreferenceToIvr < ActiveRecord::Migration[5.0]
  def change
    add_column :ivrs, :preference, :json, default: {"service_or_resource" => "Services"}
  end
end
