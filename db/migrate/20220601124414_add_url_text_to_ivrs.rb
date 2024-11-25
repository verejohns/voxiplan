class AddUrlTextToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :url_text, :string
  end
end
