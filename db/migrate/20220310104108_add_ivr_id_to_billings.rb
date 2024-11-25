class AddIvrIdToBillings < ActiveRecord::Migration[5.2]
  def change
    add_column :billings, :ivr_id, :integer
  end
end
