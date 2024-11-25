class AddMessageSectionToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :message_section, :string, default: "spoken"
  end
end
