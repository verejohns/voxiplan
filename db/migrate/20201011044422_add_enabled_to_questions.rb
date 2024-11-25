class AddEnabledToQuestions < ActiveRecord::Migration[5.0]
  def change
    add_column :questions, :enabled, :boolean
  end
end
