class AddClientIdToResourcesAndServices < ActiveRecord::Migration[5.0]
  def change
    add_reference :resources, :client, foreign_key: true
    add_reference :services, :client, foreign_key: true
  end
end
