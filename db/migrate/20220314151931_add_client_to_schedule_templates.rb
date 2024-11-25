class AddClientToScheduleTemplates < ActiveRecord::Migration[5.2]
  def change
    add_reference :schedule_templates, :client, foreign_key: true
  end
end
