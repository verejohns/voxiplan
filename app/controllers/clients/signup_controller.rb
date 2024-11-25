module Clients
  class SignupController < ApplicationController
    include ApplicationHelper
    before_action :clear_flash
    require 'ory-client'

    def new
      if session[:current_organization]
        @organization = session[:current_organization].name
      end

      redirect_to root_path and return if params["flow"].nil?

      @flow = params["flow"]

      api_instance = get_api_instance

      opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      getFlow = api_instance.get_registration_flow(params["flow"], opts)

      @csrf_token = getFlow.ui.nodes[0].attributes.value

      flash[:error] = getFlow.ui.messages[0].text unless getFlow.ui.messages.nil?

      getFlow.ui.nodes.each do |node|
        flash[:error] = node.messages[0].text unless node.messages.count.zero?
      end
    rescue OryClient::ApiError => e
      puts e
    end

    # GET /resource/edit
    # def edit
    #   super
    # end

    # PUT /resource
    # def update
    #   super
    # end

    # DELETE /resource
    # def destroy
    #   super
    # end

    # GET /resource/cancel
    # Forces the session data which is usually expired after sign
    # in to be expired now. This is useful if the user wants to
    # cancel oauth signing in/up in the middle of the process,
    # removing all OAuth session data.
    # def cancel
    #   super
    # end

    # protected

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_sign_up_params
    #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
    # end

    # If you have extra params to permit, append them to the sanitizer.
    # def configure_account_update_params
    #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
    # end

    # The path used after sign up.
    def after_sign_up_path_for(resource)
      if cookies[:processType].nil?
        # root_path
        begin
          query = {
            'name'     => resource.full_name,
            'email'      => resource.email,
            'phone' => resource.phone,
            'user_id'   => resource.uid,
            'signed_up_at' => resource.created_at,
            'custom_properties' => {'displayLanguage': resource.preferred_locale || 'en'}
          }
          headers = {
            'Content-Type'  => 'application/json',
            'Authorization' => "Bearer #{ENV['gist_api_key']}"
          }

          HTTParty.post(
            "https://api.getgist.com/contacts",
            :query => query,
            :headers => headers
          )
        rescue => e
          puts e
        end
        root_path
      else
        timify_cred_timify_credential_index_path
      end

    end

    protected

    def update_resource(resource, params)
      if params["current_password"].present?
        @update_password = true
        return super
      else
        params.delete :current_password
      end
      resource.update_without_password(params)
    end

    def after_update_path_for(resource)
      edit_client_registration_path
    end

    def send_notification_email
      ClientNotifierMailer.generic_email(
        to: ENV['ERROR_MAIL_RECIPIENTS'],
        subject: 'Fake signup attempt.',
        body: params.to_yaml
      ).deliver

      redirect_to root_path, error: 'Please contact our support.'
    end
  end
end