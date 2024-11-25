class AddIsIncludeCancelLinkToReminders < ActiveRecord::Migration[5.2]
  def change
    add_column :reminders, :is_include_cancel_link, :bool
  end
end
