module Clients
  class OryController < ApplicationController
    include ApplicationHelper
    before_action :clear_flash
    require 'ory-client'

    def logout
      api_instance = get_api_instance

      get_opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      getFlow = api_instance.create_browser_logout_flow(get_opts)

      redirect_to getFlow.logout_url
    rescue Exception => e
      puts '-------------------- logout error ------------------------------'
      puts e

      session.clear

      redirect_to root_path
    end

    def invitation
      invitation = Invitation.find(params[:id])

      if invitation and invitation.status == "pending"
        invitation.update_columns(status: "accepted")
        session[:current_organization] = Organization.find(invitation.organization_id)

        if current_client && current_client.email == invitation.to_email
          # client logged in currently
          addRelationTuple("/organization-" + invitation.organization_id.to_s, invitation.role, "client-" + current_client.id.to_s)
        else
          client = Client.find_by_email(invitation.to_email)
          if client
            # client registered, but not logged in
            addRelationTuple("/organization-" + invitation.organization_id.to_s, invitation.role, "client-" + client.id.to_s)
          else
            # client didn't registered
            invitation.update_columns(status: "accepting")
          end
        end
      end

      redirect_to root_path
    end

    def process_old_client(client)
      params = {
        "schema_id": ENV['ORY_IDENTITY_SCHEMA_ID'],
        "traits": {
          "email": client["email"],
          "phone": client["phone"],
          "language": client["preferred_locale"] || 'en',
          "firstName": client["first_name"],
          "lastName": client["last_name"]
        },
        "credentials": {
          "password": {
            "config": {
              "hashed_password": client["encrypted_password"]
            }
          }
        }
      }

      createIdentifier = HTTParty.post(ENV['ORY_SDK_KETO_URL'] + "/admin/identities", { headers: { 'Content-Type' => "application/json", 'Authorization' => 'Bearer ' + ENV['ORY_ACCESS_TOKEN'] }, body: JSON.generate(params) })

      Client.find_by_email(client["email"]).update_columns(ory_id: createIdentifier["id"], is_welcomed: true) unless createIdentifier["id"].nil?

      organization = Organization.create({ status: "active", client_id: client["id"], name: client["company"].present? ? client["company"] : client["first_name"] + " " + client["last_name"] })

      addRelationTuple("/organization-" + organization.id.to_s, "owner", "client-" + client["id"].to_s)
      addRelationTupleSet("/organization-" + organization.id.to_s, "manage", "/organization-" + organization.id.to_s, "owner")
      addRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/organization-" + organization.id.to_s, "owner")
      addRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/app", "super-admin")

      addRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "owner")
      addRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "member")

      addRelationTupleSet("/app", "all", "/organization-" + organization.id.to_s, "owner")

      addRelationTupleSet("/organization-" + organization.id.to_s + "/billing", "manage", "/organization-" + organization.id.to_s, "owner")
    end

    def ory_init
      require "json"
      # clients_list = File.open "#{ENV['APP_ENV']}-clients.json"
      # external_list = File.open "external.json"

      old_clients = Client.all
      # old_clients = JSON.load clients_list
      # external_clients = JSON.load external_list

      old_clients.each do |client|
        process_old_client(client)
      end

      # external_clients.each do |external_client|
      #   unless Client.find_by_email(external_client["customer[email]"])
      #     client = Client.create({ :email => external_client["customer[email]"], company: external_client["customer[company]"], :password => "password", :first_name => external_client["customer[first_name]"], :last_name => external_client["customer[last_name]"], :phone => external_client["customer[phone]"], :country => external_client["billing_address[country]"], :preferred_locale => external_client["customer[locale]"], :time_zone => "", :phone_country => external_client["billing_address[country]"], :country_code => external_client["billing_address[country]"], :sign_in_count => 1 })
      #
      #     process_old_client(client)
      #   end
      # end

      redirect_to root_path
    rescue => e
      puts e.message
      puts "****** The existed client's ory init setting is failure ******"
    end

    def recovery
      @flow = params["flow"]

      api_instance = get_api_instance

      begin
        opts = {
          :cookie => request.headers["HTTP_COOKIE"]
        }

        getFlow = api_instance.get_recovery_flow(params["flow"], opts)

        @state = getFlow.state
        @csrf_token = getFlow.ui.nodes[0].attributes.value
        @email = getFlow.ui.nodes[4].attributes.value if getFlow.state == 'sent_email'

        flash[:notice] = getFlow.ui.messages[0].text unless getFlow.ui.messages.nil?
      rescue OryClient::ApiError => e
        puts e
      end
    end

    def recovery_client
      formData = JSON.parse(params.to_json)

      recoveryResponse = HTTParty.post(ENV['ORY_URL'] + "/self-service/recovery/flows?id=" + formData["flowId"], { headers: { 'Accept' => "application/json" }, body: JSON.generate( "email" => formData["email"], "method" => 'link' ) })

      if recoveryResponse.code == 200
        flash[:success] = recoveryResponse["ui"]["messages"][0]["text"]
      else
        flash[:error] = t('errors.invalid_email_password')
      end

      redirect_back fallback_location: client_password_path and return
    rescue => e
      puts e
      flash[:error] = t('errors.something_wrong')

      redirect_back fallback_location: client_password_path and return
    end

    def verification
      @flow = params["flow"]

      api_instance = get_api_instance

      opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      redirect_to root_path and return if params["flow"].nil?

      getFlow = api_instance.get_verification_flow(params["flow"], opts)
      puts "************ verification_getFlow **************"
      puts getFlow
      if getFlow.state == "choose_method" && current_client
        send_flow_body = {
          "csrf_token" => getFlow.ui.nodes[0].attributes.value,
          "email" => current_client.email,
          "method" => 'code'
        }

        submitFlow = api_instance.update_verification_flow(params["flow"], send_flow_body, opts)
        puts "************ verification_submitFlow **************"
        puts submitFlow

        flash[:error] = submitFlow.ui.messages[0].text if submitFlow.ui.messages.length() == 1

        redirect_back fallback_location: verification_init_path and return
      elsif getFlow.state == 'sent_email'
        @state = getFlow.state
        @csrf_token = getFlow.ui.nodes[3].attributes.value
        @code = getFlow.ui.nodes[0].attributes.value

        flash[:notice] = getFlow.ui.messages[0].text unless getFlow.ui.messages.nil?
      else
        redirect_to root_path and return
      end
    rescue OryClient::ApiError => e
      puts e
    end

    def reset
      api_instance = get_api_instance

      opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      if params[:flow]
        getFlow = api_instance.get_settings_flow(params[:flow], opts)

        @csrf_token = getFlow.ui.nodes[0].attributes.value
        @flow = params[:flow]
      else
        flash[:error] = t('errors.something_wrong')

        redirect_back fallback_location: root_path and return
      end

      if session[:ory_session_token] && session[:ory_identity] && session[:ory_identity].id == getFlow.identity.id
        settings_form = {
          csrf_token: @csrf_token,
          flowId: @flow
        }

        session[:settings_form] = settings_form

        redirect_to profile_path('settings')
      end

      flash[:success] = getFlow.ui.messages[0].text unless getFlow.ui.messages.nil?
    rescue OryClient::ApiError => e
      puts e
    end

    def whoami
      api_instance = get_api_instance

      opts = {
        :cookie => request.headers["HTTP_COOKIE"]
      }

      api_instance.to_session(opts)
    rescue => e
      puts "*********** ory whoami api error *****************"
      puts e

      if e.code == 401
        return 'Unauthorized'
      end

      return nil
    end

    def post_settings
      session_identity = whoami

      if session_identity
        redirect_to root_path and return if session_identity == "Unauthorized"

        if session[:ory_identity].nil? || session[:ory_session_token].nil? || session[:ory_identity].id != session_identity.identity.id
          session[:ory_identity] = session_identity.identity
          session[:ory_session_token] = cookies["ory_session_" + ENV['ORY_SDK_KETO_URL'].split('//')[1].split('.')[0].gsub('-', '')]
        else
          client = Client.find_by_ory_id(session[:ory_identity].id)
          language = session_identity.identity.traits[:language]

          if client
            phone_number = Phonelib.parse(session_identity.identity.traits[:phone]).e164
            phone_number = phone_number.gsub('+', '')
            client.update_columns(email: session_identity.identity.traits[:email], first_name: session_identity.identity.traits[:firstName], last_name: session_identity.identity.traits[:lastName],
                                  phone: phone_number, language: language, :country => session[:profile_form][:country], #currency_code: currency_code,
                                  :time_zone => session[:profile_form][:timezone], :phone_country => session[:profile_form][:phone_country], :company => session[:profile_form][:company])

            language = 'en' unless language =='en' || language == 'fr' || language == 'de' || language == 'it' || language == 'pt' || language == 'es'
            ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
            ChargeBee::Customer.update(session[:current_organization].id,{ :locale => language})

          end
        end
      end

      redirect_to profiles_path
    rescue OryClient::ApiError => e
      puts "************ ory settings error *************"
      puts e
      redirect_to profiles_path
    end

    def registration
      client_form = {
        country: params[:country],
        time_zone: params[:time_zone],
        phone_country: params[:phone_country],
        country_code: params[:country_code],
        receive_email: params[:receive_email]
      }

      session[:client_form] = client_form

      return render json: { success: true }, status: 200
    rescue => e
      puts e
      return render json: { success: false, message: t('errors.something_wrong') }, status: 500
    end

    def error
      api_instance = get_api_instance

      redirect_to root_path and return if params[:id].nil?

      getFlow = api_instance.get_flow_error(params[:id])

      @code = getFlow.error[:code]
      @message = getFlow.error[:message] || ''
      @reason = getFlow.error[:reason] || ''
    rescue OryClient::ApiError => e
      puts e
    end
  end
end
