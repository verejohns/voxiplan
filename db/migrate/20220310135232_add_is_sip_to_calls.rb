class AddIsSipToCalls < ActiveRecord::Migration[5.2]
  def change
    add_column :calls, :is_sip, :bool
  end
end
