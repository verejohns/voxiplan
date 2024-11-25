class AddOrdernoToQuestions < ActiveRecord::Migration[5.2]
  def change
    add_column :questions, :orderno, :integer
  end
end
