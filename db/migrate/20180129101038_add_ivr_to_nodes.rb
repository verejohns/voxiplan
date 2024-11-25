class AddIvrToNodes < ActiveRecord::Migration[5.0]
  def change
    add_reference :nodes, :ivr, foreign_key: true
  end
end
