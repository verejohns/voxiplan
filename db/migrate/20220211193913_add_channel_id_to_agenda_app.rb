class AddChannelIdToAgendaApp < ActiveRecord::Migration[5.2]
  def change
    add_column :agenda_apps, :channel_id, :string
  end
end
