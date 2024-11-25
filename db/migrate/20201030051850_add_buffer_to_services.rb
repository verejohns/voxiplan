class AddBufferToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :buffer, :integer, default: 0
  end
end
