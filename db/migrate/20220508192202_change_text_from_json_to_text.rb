class ChangeTextFromJsonToText < ActiveRecord::Migration[5.2]
  def change
    change_column :service_notifications, :text, :text
  end
end
