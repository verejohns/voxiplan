class AddIsTransferToCustomers < ActiveRecord::Migration[5.2]
  def change
    add_column :customers, :is_transfer, :boolean, default: true
    Customer.all.update(is_transfer: true)
  end
end
