class AddAttachmentLogoToIvrs < ActiveRecord::Migration[5.0]
  def self.up
    remove_column :ivrs, :logo
    change_table :ivrs do |t|
      t.attachment :logo
    end
  end

  def self.down
    add_column :ivrs, :logo, :string
    remove_attachment :ivrs, :logo
  end
end
