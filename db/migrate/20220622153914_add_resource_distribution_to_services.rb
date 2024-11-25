class AddResourceDistributionToServices < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :resource_distribution, :string, default: "invitee"
  end
end
