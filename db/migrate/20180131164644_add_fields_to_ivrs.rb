class AddFieldsToIvrs < ActiveRecord::Migration[5.0]
  def change
    add_column :ivrs, :confirmation_sms, :boolean, default: false
    add_column :ivrs, :voice, :string
    add_column :ivrs, :agent_number, :string
  end
end
