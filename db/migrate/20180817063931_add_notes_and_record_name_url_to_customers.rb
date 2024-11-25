class AddNotesAndRecordNameUrlToCustomers < ActiveRecord::Migration[5.0]
  def change
    add_column :customers, :notes, :text
    add_column :customers, :recorded_name_url, :string
  end
end
