class AgendaConnectController < ApplicationController
  require 'uri'
  skip_before_action :verify_authenticity_token

  before_action :authorize_webhook, only: :incoming_message

  def connect
    cronofy_client = current_client.create_cronofy

    code = [params[:code]]
    response = cronofy_client.get_token_from_code(code, cronofy_auth_callback_url)
    new_agenda = current_client.create_agenda

    return_url = session[:cronofy_auth_success_callback_url] + "&success=true&access_token=" + response.access_token + "&refresh_token=" + response.refresh_token +
      "&profile_id=" + response.linking_profile.profile_id + "&profile_name=" + response.linking_profile.profile_name + "&provider_name=" + response.linking_profile.provider_name +
      "&account_id=" + response.account_id + "&agenda_id=" + new_agenda.id.to_s

    redirect_to return_url
  rescue => e
    puts e
    redirect_to root_path
  end
end
