class AddResponseFormatToServices < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :response_format, :string, default: 'slots'
  end
end
