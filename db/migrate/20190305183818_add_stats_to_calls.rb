class AddStatsToCalls < ActiveRecord::Migration[5.0]
  def change
    add_column :calls, :to_state, :string
    add_column :calls, :caller_country, :string
    add_column :calls, :caller_state, :string
    add_column :calls, :to_zip, :string
    add_column :calls, :caller_zip, :string
    add_column :calls, :to_country, :string
    add_column :calls, :called_zip, :string
    add_column :calls, :called_city, :string
    add_column :calls, :called_country, :string
    add_column :calls, :caller_city, :string
    add_column :calls, :from_country, :string
    add_column :calls, :to_city, :string
    add_column :calls, :from_city, :string
    add_column :calls, :called_state, :string
    add_column :calls, :from_zip, :string
    add_column :calls, :from_state, :string
    add_column :calls, :call_type, :string
    add_column :calls, :appointment_type, :string
    add_column :calls, :client_type, :string
  end
end
