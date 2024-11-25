class AddParentCallSidToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :parent_call_sid, :string
  end
end
