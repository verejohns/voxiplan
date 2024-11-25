class AddIvrReferenceToCalls < ActiveRecord::Migration[5.0]
  def change
    add_reference :calls, :ivr, foreign_key: true
  end
end
