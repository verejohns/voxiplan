class ProfilesController < ApplicationController
  include ApplicationHelper
  require 'ory-client'

  before_action :check_ory_session, except: [:closed_account, :update_locale]
  skip_before_action :verify_authenticity_token

  layout 'layout', except: [:closed_account]

  def index
    redirect_to profile_path('overview')
  end

  def show
    session[:current_organization] = current_client.organizations.first unless session[:current_organization]

    @profile_section = params[:id]
    @languages = LanguageList::COMMON_LANGUAGES
    @user_language = current_client.language || 'en'

    if @profile_section == "settings"
      @flow = session[:settings_form][:flowId]
      @csrf_token = session[:settings_form][:csrf_token]
    end

    @isVerified = isVerified

    unless isVerified
      api_instance = get_api_instance

      initFlow = api_instance.create_native_verification_flow()
      @flow = initFlow.id

      flash[:error] = t('profile.overview.verify_required')
    end
  rescue OryClient::ApiError => e
    puts e
  end

  def edit_profile
    profile_form = {
      country: params[:country],
      company: params[:company],
      timezone: params[:timezone],
      phone_country: params[:phone_country]
    }

    session[:profile_form] = profile_form

    return render json: { success: true }, status: 200
  rescue => e
    puts e
    return render json: { success: false, message: t('errors.something_wrong') }, status: 500
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

  def isVerified
    if session[:ory_identity].traits[:email] == "admin@voxiplan.com"
      return true
    end
    unless session[:ory_identity].verifiable_addresses[0].verified
      session_identity = whoami

      session[:ory_identity] = session_identity && session_identity != "Unauthorized" ? session_identity.identity : nil
    end

    session[:ory_identity] ? session[:ory_identity].verifiable_addresses[0].verified : false
  end

  def send_verification
    api_instance = get_api_instance

    getFlow = api_instance.get_verification_flow(params[:id])

    send_flow_body = {
      "csrf_token" => getFlow.ui.nodes[0].attributes.value,
      "email" => current_client.email,
      "method" => 'link'
    }

    submitFlow = api_instance.update_verification_flow(params[:id], send_flow_body)

    flash[:success] = submitFlow.ui.messages[0].text if submitFlow.ui.messages.length() == 1

    redirect_back fallback_location: profile_path and return
  rescue OryClient::ApiError => e
    puts e
  end

  def update_locale
    locale = params[:locale]
    cookies[:locale] = locale
    if current_client
      current_client.update_column(:preferred_locale, locale)
      ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
      ChargeBee::Customer.update(session[:current_organization].id,{ :locale => locale == 'el' ? 'en' : locale})
      # redirect_to root_path(locale: locale)
      redirect_url = params[:current_page].gsub(/locale=[a-z][a-z]/, "locale=#{locale}")
      redirect_to redirect_url
    else
      redirect_to request.referrer
    end
  end

  def close_account
    HTTParty.delete(ENV['ORY_SDK_KETO_URL'] + "/admin/identities/" + current_client.ory_id, {headers: { 'Authorization' => 'Bearer ' + ENV['ORY_ACCESS_TOKEN'] } })

    # api_instance = get_api_instance
    #
    # get_opts = {
    #   :cookie => request.headers["HTTP_COOKIE"]
    # }
    #
    # deleteIdentity = api_instance.delete_identity(current_client.ory_id, get_opts)
    # puts deleteIdentity

    if checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
      invitations = Invitation.where(organization_id: session[:current_organization].id, status: "accepted")
      invitations.each do |invitation|
        client = Client.find_by_email(invitation.to_email)
        deleteRelationTuple("/organization-" + session[:current_organization].id.to_s, "member", "client-" + client.id.to_s)
      end
      invitations.destroy_all

      # Chargebee Subscription Cancel
      # end_of_term (optional, boolean, default=false): Set this to true if you want to cancel the subscription at the end of the current subscription billing cycle. The subscription status changes to non_renewing.
      ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
      result = ChargeBee::Subscription.cancel_for_items(session[:current_organization].chargebee_subscription_id,{
        :end_of_term => true
      })
      puts result

      Organization.find(session[:current_organization].id).destroy
    end

    invitations = Invitation.where(status: "accepted", to_email: current_client.email)
    invitations.each do |invitation|
      deleteRelationTuple("/organization-" + invitation.organization_id, "member", "client-" + current_client.id.to_s)
    end
    invitations.destroy_all

    if checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
      deleteRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
      organization = session[:current_organization]
    else
      organization = Organization.find_by_client_id(current_client.id)
      deleteRelationTuple("/organization-" + organization.id.to_s, "owner", "client-" + current_client.id.to_s) if organization
    end

    if organization
      deleteRelationTupleSet("/organization-" + organization.id.to_s, "manage", "/organization-" + organization.id.to_s, "owner")
      deleteRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/organization-" + organization.id.to_s, "owner")
      deleteRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/app", "super-admin")

      if organization.chargebee_subscription_plan
        deleteRelationTupleSet("/app", organization.chargebee_subscription_plan, "/organization-" + organization.id.to_s, "owner")
        deleteRelationTupleSet("/app", organization.chargebee_subscription_plan, "/organization-" + organization.id.to_s, "member")
      else
        deleteRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "owner")
        deleteRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "member")
      end

      deleteRelationTupleSet("/app", "all", "/organization-" + organization.id.to_s, "owner")
      deleteRelationTupleSet("/organization-" + organization.id.to_s + "/billing", "manage", "/organization-" + organization.id.to_s, "owner")

      unless checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
        organization.destroy
      end
    end

    current_client.ivrs.each do |ivr|
      VoxiSession.where(ivr_id: ivr.id).destroy_all
      AgendaApp.where(ivr_id: ivr.id).destroy_all
    end

    current_client.destroy

    session.clear

    render json: {result: 'success'}
  rescue => e
    puts e
    render json: {result: 'error', message: e.message}
  end

  def closed_account

  end
end
