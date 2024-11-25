class AddBufferAfterToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :buffer_after, :integer, default: 0
  end
end
