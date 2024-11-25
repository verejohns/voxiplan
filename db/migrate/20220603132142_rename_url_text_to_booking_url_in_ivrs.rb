class RenameUrlTextToBookingUrlInIvrs < ActiveRecord::Migration[5.2]
  def change
    change_table :ivrs do |t|
      t.rename :url_text, :booking_url
    end
  end
end
