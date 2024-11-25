class AddBusinessHoursToAgendaApp < ActiveRecord::Migration[5.0]
  def change
    hash = {
          mon: [{from: '09:00', to: '17:00'}],
          tue: [{from: '09:00', to: '17:00'}],
          wed: [{from: '09:00', to: '17:00'}],
          thu: [{from: '09:00', to: '17:00'}],
          fri: [{from: '09:00', to: '17:00'}]
        }
    add_column :agenda_apps, :default_resource_availability, :json, default: hash
  end
end
