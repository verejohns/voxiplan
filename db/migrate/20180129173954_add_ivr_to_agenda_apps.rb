class AddIvrToAgendaApps < ActiveRecord::Migration[5.0]
  def change
    add_reference :agenda_apps, :ivr, foreign_key: true
  end
end
