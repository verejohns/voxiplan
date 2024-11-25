class AddScheduleTemplateIdToResources < ActiveRecord::Migration[5.2]
  def change
    add_column :resources, :schedule_template_id, :integer, default: 0
  end
end
