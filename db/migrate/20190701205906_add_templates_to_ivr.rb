class AddTemplatesToIvr < ActiveRecord::Migration[5.0]
  def change
    add_column :ivrs, :templates, :json, default: {}
  end
end
