class FixColumnName < ActiveRecord::Migration[5.0]
  def change
    rename_column :questions, :type, :answer_type
  end
end
