class ChangeDefaultValueOfPreferenceInServices < ActiveRecord::Migration[5.0]
  def change
    change_column_default :services, :preference, {"pre_confirmation"=>"false", "add_invitee"=>"true"}
  end
end
