class AddFixedLineNumToCustomers < ActiveRecord::Migration[5.0]
  def change
    add_column :customers, :fixed_line_num, :string
  end
end
