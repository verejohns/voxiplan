module Clients
  class SessionsController < ApplicationController
    include ApplicationHelper
    before_action :clear_flash
    require 'ory-client'

    def new
      if session[:current_organization]
        @organization = session[:current_organization].name
      end

      @flow = params["flow"]

      api_instance = get_api_instance

      opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      return redirect_to root_path unless params.has_key?(:flow)

      unless params["flow"].nil? && params["flow"] != ''
        getFlow = api_instance.get_login_flow(params["flow"], opts)

        @csrf_token = getFlow.ui.nodes[0].attributes.value

        unless getFlow.ui.messages.nil?
          if getFlow.ui.messages[0].id == 1010003
            session.clear

            flash[:error] = t('ory.infor.session_expired')
          else
            flash[:error] = getFlow.ui.messages[0].text
          end
        end
      end
    rescue OryClient::ApiError => e
      puts e
    end

    # DELETE /resource/sign_out
    def destroy
      super
    end

    private
    def after_sign_in_path_for(resource_or_scope)
      if cookies[:processType].nil?
        if current_client.nil?
          session.clear
          destroy
          redirect_to root_path
        end

        if current_client.sign_in_count == 1
          root_path
        else
          services_path
        end
      else
        timify_cred_timify_credential_index_path
      end
    end
  end
end
