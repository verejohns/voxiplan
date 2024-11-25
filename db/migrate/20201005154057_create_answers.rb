class CreateAnswers < ActiveRecord::Migration[5.0]
  def change
    create_table :answers do |t|
      t.string :question_text
      t.string :text
      t.string :customer_id
      t.string :appointment_id
    end
  end
end
