class AddAgendaSignUpFieldsToClients < ActiveRecord::Migration[5.0]
  def change
    add_column :clients, :agenda_sign_up_fields, :json, default: {}
  end
end
