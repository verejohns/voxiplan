class WebhookCallDetail < ApplicationRecord
  belongs_to :client, optional: true
  after_update :unauthorize_token

  def unauthorize_token
    AgendaApp.where(timify_access_token: self.accessToken).update_all(timify_access_token: nil) if  self.auth_data["type"] == "unauthorized"
  end
end
