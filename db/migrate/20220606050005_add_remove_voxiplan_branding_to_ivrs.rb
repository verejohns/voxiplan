class AddRemoveVoxiplanBrandingToIvrs < ActiveRecord::Migration[5.2]
  def change
    add_column :ivrs, :remove_voxiplan_branding, :bool, default: false
  end
end
