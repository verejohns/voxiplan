class AddAssistantNameToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :assistant_name, :string, default: 'Laura'
  end
end
