class AddOrdernoToQuestionOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :question_options, :orderno, :integer
  end
end
