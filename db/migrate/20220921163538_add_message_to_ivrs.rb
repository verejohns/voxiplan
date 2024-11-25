class AddMessageToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :message, :string
  end
end
