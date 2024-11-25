class AddScheduleTemplateIdToServices < ActiveRecord::Migration[5.2]
  def change
    add_column :services, :schedule_template_id, :integer, default: 0
  end
end
