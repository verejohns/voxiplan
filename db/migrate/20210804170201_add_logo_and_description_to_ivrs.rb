class AddLogoAndDescriptionToIvrs < ActiveRecord::Migration[5.0]
  def up
    add_column :ivrs, :use_branding, :boolean, default: false
    add_column :ivrs, :logo, :string
    add_column :ivrs, :description, :text
  end

  def down
    remove_column :ivrs, :use_branding
    remove_column :ivrs, :logo
    remove_column :ivrs, :description
  end
end
