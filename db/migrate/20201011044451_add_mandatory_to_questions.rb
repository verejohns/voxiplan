class AddMandatoryToQuestions < ActiveRecord::Migration[5.0]
  def change
    add_column :questions, :mandatory, :boolean
  end
end
