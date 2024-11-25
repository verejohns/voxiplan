class AddIvrToTextMessages < ActiveRecord::Migration[5.0]
  def change
    add_reference :text_messages, :ivr, foreign_key: true
  end
end
