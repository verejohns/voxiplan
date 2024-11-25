class AddSMSPriceToTextMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :text_messages, :sms_price, :decimal, precision: 5, scale: 2
  end
end
