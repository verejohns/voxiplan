class CreateScheduleTemplates < ActiveRecord::Migration[5.2]
  def change
    create_table :schedule_templates do |t|
      t.string :template_name
      t.boolean :is_default
      t.timestamps
    end
  end
end
