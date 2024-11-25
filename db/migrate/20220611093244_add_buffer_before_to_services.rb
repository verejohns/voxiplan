class AddBufferBeforeToServices < ActiveRecord::Migration[5.0]
  def change
    add_column :services, :buffer_before, :integer, default: 0
  end
end
