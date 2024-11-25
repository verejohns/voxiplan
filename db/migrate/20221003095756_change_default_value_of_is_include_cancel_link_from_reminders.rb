class ChangeDefaultValueOfIsIncludeCancelLinkFromReminders < ActiveRecord::Migration[5.2]
  def change
    change_column_default :reminders, :is_include_cancel_link, from: nil, to: true
  end
end
