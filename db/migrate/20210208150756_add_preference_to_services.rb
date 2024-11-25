class AddPreferenceToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :preference, :json, default: {"pre_confirmation" => "false"}
  end
end
