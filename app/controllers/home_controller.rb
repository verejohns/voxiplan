class HomeController < ApplicationController
  include ApplicationHelper
  before_action :check_ory_session
  require 'ory-client'

  # layout 'layout'

  def index
    if current_client.nil?
      session.clear

      redirect_to logout_client_path and return
    end

    session[:current_organization] = current_client.organizations.first unless session[:current_organization]

    invitation = Invitation.where(to_email: current_client.email, status: "accepting").first

    if invitation
      # client accepted an invitation and didn't registered before
      invitation.update_columns(status: "accepted")
      addRelationTuple("/organization-" + invitation.organization_id.to_s, invitation.role, "client-" + current_client.id.to_s)
    end

    if isVerified || current_client.is_welcomed
      if (current_client.server_region.nil? || current_client.server_region == "") && current_client.is_welcomed
        redirect_to old_onboarding_path and return
      end

      if current_client.sign_in_count > 1 && current_client.is_welcomed
        redirect_to services_path and return
      else
        if checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
          redirect_to onboarding_path and return
        else
          redirect_to member_onboarding_path and return
        end
      end
    else
      redirect_to verification_init_path and return
    end
  rescue => e
    puts e
    session.clear
    redirect_to logout_client_path and return
  end

  def set_server_region
    init_application_calendar = ApplicationCalendar.create({ :name => session[:current_organization].name, :organization_id => session[:current_organization].id, :client_id => current_client.id })
    application_calendar_id = 'cronofy_calendar_' + init_application_calendar.id
    cronofy = current_client.create_cronofy
    application_calendar = cronofy.application_calendar(application_calendar_id)
    access_token = application_calendar.access_token
    refresh_token = application_calendar.refresh_token
    calendar_sub = application_calendar.sub

    cronofy = current_client.create_cronofy(access_token: access_token, refresh_token: refresh_token)
    calendars = cronofy.list_calendars
    created_calendar = calendars.select{|c| c.calendar_name == application_calendar_id}
    created_calendar = created_calendar[0]
    calendar_id = created_calendar.calendar_id

    init_application_calendar.update_columns(calendar_id: calendar_id, conflict_calendars: calendar_id, calendar_name: created_calendar.calendar_name,
      access_token: access_token, refresh_token: refresh_token, application_sub: calendar_sub)

    default_resouorces = current_client.resources.where(agenda_type: nil, calendar_type: "my_calendar", my_calendar_type: "default", client_id: current_client.id)
    default_resouorces.update_all(calendar_id: calendar_id, conflict_calendars: calendar_id, application_calendar_id: calendar_id,
      application_access_token: access_token, application_refresh_token: refresh_token, application_sub: calendar_sub)

    current_client.update_columns(server_region: "DE")
    redirect_to root_path
  end

  def set_server_region_member
    current_client.update_columns(server_region: "DE", is_welcomed: true)
    current_client.increment!(:sign_in_count, 1)
    current_client.ivrs.each do |ivr|
      ivr.update_columns(booking_url: ivr.uid)
    end
    redirect_to root_path
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

  def verification
    api_instance = get_api_instance

    # initFlow = api_instance.create_native_verification_flow()
    # puts initFlow
    #
    # opts = {
    #   :cookie => request.headers["HTTP_COOKIE"]
    # }
    #
    # getFlow = api_instance.get_verification_flow(initFlow.id)
    # puts getFlow
    #
    # send_flow_body = {
    #   "email" => current_client.email,
    #   "method" => 'code'
    # }
    #
    # submitFlow = api_instance.update_verification_flow(getFlow.id, send_flow_body)
    # puts submitFlow

    # verify_flow_body = {
    #   "code" => "892694",
    #   "method" => 'code'
    # }
    #
    # verifyFlow = api_instance.update_verification_flow("13542409-75b8-4fd7-b075-1d483863f721", verify_flow_body)
    # puts verifyFlow

    redirect_to root_path if isVerified
  rescue => e
    puts e
  end

  def old_onboarding
    @server_regions = {'US': 'US', 'DE': 'EU', 'UK': 'GB', 'CA': 'CA', 'AU': 'AU', 'SG': 'SG'}
    @selected_server_region = 'DE'
    @browser_locale = get_browser_locale.to_s
  end

  def member_onboarding
    main_onboarding

    @server_regions = {'US': 'US', 'DE': 'EU', 'UK': 'GB', 'CA': 'CA', 'AU': 'AU', 'SG': 'SG'}
    @selected_server_region = 'DE'
    @browser_locale = get_browser_locale.to_s
  end

  def main_onboarding
    redirect_to verification_init_path unless isVerified
    redirect_to services_path if current_client.sign_in_count > 1 && current_client.is_welcomed
    if current_client.schedule_templates.count.zero?
      schedule_template = current_client.schedule_templates.new(template_name: t('availabilities.working_hours'), is_default: true)
      schedule_template.save
      availablities = Availability.new(schedule_template_id: schedule_template.id)
      availablities.save
    end

    if current_client.calendar_setting.nil?
      calendar_setting = CalendarSetting.new(client_id: current_client.id, max_time: '23:55:00')
      calendar_setting.save
    end

    current_client.services.each do |service|
      if service.questions.where(answer_type: 'mandatory').count.zero?
        question = service.questions.new(text: 'first_lastname', answer_type: 'mandatory', enabled: true)
        question.save
      end
    end

    current_client.ivrs.each do |ivr|
      ivr_id = ivr.id
      ivr.client.services.where(ivr_id: ivr_id).each do |service|
        unless service.reminder
          email_invitee_subject = t('mails.reminder_email_invitee.subject')
          email_invitee_body = t('mails.reminder_email_invitee.body')
          sms_invitee_body = t('mails.reminder_sms_invitee.body')
          Reminder.create(advance_time_offset: 10, advance_time_duration: '-', time: '', sms: false, email: false, email_subject: email_invitee_subject, text: email_invitee_body, email_subject_host: email_invitee_subject, text_host: email_invitee_body,
                          sms_text: sms_invitee_body, client_id: current_client.id, ivr_id: ivr_id, service_id: service.id, enabled: true, is_include_agenda: false)
        end
      end
    end

    ISO3166.configuration.enable_currency_extension!
    country = ISO3166::Country[current_client.phone_country]
    current_client.update_columns(currency_code: country.currency.iso_code == 'EUR' ? 'EUR' : 'USD')
  end

  def onboarding
    main_onboarding

    if checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s) && ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id).count.zero?
      init_application_calendar = ApplicationCalendar.create({ :name => session[:current_organization].name, :organization_id => session[:current_organization].id, :client_id => current_client.id })
      application_calendar_id = 'cronofy_calendar_' + init_application_calendar.id
      cronofy = current_client.create_cronofy
      application_calendar = cronofy.application_calendar(application_calendar_id)

      cronofy = current_client.create_cronofy(access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
      calendars = cronofy.list_calendars
      created_calendar = calendars.select{|c| c.calendar_name == application_calendar_id}

      init_application_calendar.update_columns(
        calendar_id: created_calendar[0].calendar_id,
        conflict_calendars: created_calendar[0].calendar_id,
        calendar_name: created_calendar[0].calendar_name,
        access_token: application_calendar.access_token,
        refresh_token: application_calendar.refresh_token,
        application_sub: application_calendar.sub,
        )

      default_resouorces = current_client.resources.where(calendar_type: "my_calendar", my_calendar_type: "default", client_id: current_client.id)

      default_resouorces.update_all(
        calendar_id: created_calendar[0].calendar_id,
        conflict_calendars: created_calendar[0].calendar_id,
        application_calendar_id: created_calendar[0].calendar_id,
        application_access_token: application_calendar.access_token,
        application_refresh_token: application_calendar.refresh_token,
        application_sub: application_calendar.sub
      )
    end

    if (session[:current_organization].chargebee_subscription_id == "" || session[:current_organization].chargebee_subscription_id.nil?) && checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
      ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
      result = ChargeBee::Customer.create({
                                            :id => session[:current_organization].id,
                                            :first_name => current_client.first_name,
                                            :last_name => current_client.last_name,
                                            :company => session[:current_organization].name,
                                            :email => current_client.email,
                                            :locale => I18n.locale
                                          })

      result = ChargeBee::Subscription.create_with_items(result.customer.id,{
        :subscription_items => [{:item_price_id => ENV["PREMIUM_TRIAL_#{current_client.currency_code}_ID"]}]
      })

      session[:current_organization].update_columns(chargebee_seats: 1, chargebee_subscription_id: result.subscription.id, chargebee_subscription_plan: 'trial', chargebee_subscription_period: 'monthly')
      current_client.organizations.update_all(chargebee_seats: 1, chargebee_subscription_id: result.subscription.id, chargebee_subscription_plan: 'trial', chargebee_subscription_period: 'monthly')
    end

    @customize_availability = BusinessHours::DEFAULT_AVAILABILITY
    @server_regions = {'US': 'US', 'DE': 'EU', 'UK': 'GB', 'CA': 'CA', 'AU': 'AU', 'SG': 'SG'}
    @selected_server_region = 'DE'

    @browser_locale = get_browser_locale.to_s
    session[:currency_symbol] = current_client.currency_code == 'EUR' ? '€' : '$'
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

  def post_login
    session_identity = whoami

    redirect_to (ENV['ORY_URL'] || '') + '/self-service/login/browser?refresh=true' and return if session_identity == "Unauthorized"

    session[:ory_identity] = session_identity.identity
    session[:ory_session_token] = cookies["ory_session_" + ENV['ORY_SDK_KETO_URL'].split('//')[1].split('.')[0].gsub('-', '')]

    client = Client.find_by_email(session[:ory_identity].traits[:email])
    client.increment!(:sign_in_count, 1) if client

    session[:currency_symbol] = client.currency_code == 'EUR' ? '€' : '$'

    organization = client.organizations.first
    if organization && (organization.chargebee_subscription_id == "" || organization.chargebee_subscription_id.nil?) && checkRelationTuple("/organization-" + organization.id.to_s, "owner", "client-" + client.id.to_s)
      ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
      result = ChargeBee::Customer.create({
                                            :id => organization.id,
                                            :first_name => client.first_name,
                                            :last_name => client.last_name,
                                            :company => organization.name,
                                            :email => client.email,
                                            :locale => I18n.locale
                                          })

      result = ChargeBee::Subscription.create_with_items(result.customer.id,{
        :subscription_items => [{:item_price_id => ENV["PREMIUM_TRIAL_#{client.currency_code}_ID"]}]
      })

      client.organizations.update_all(chargebee_seats: 1, chargebee_subscription_id: result.subscription.id, chargebee_subscription_plan: 'trial', chargebee_subscription_period: 'monthly')
    end

    redirect_to root_path
  rescue => e
    puts e
    redirect_to root_path
  end

  def reset
    api_instance = get_api_instance

    opts = {
      :cookie => request.headers["HTTP_COOKIE"]
    }

    getFlow = api_instance.get_settings_flow(params["flow"], opts)

    @csrf_token = getFlow.ui.nodes[0].attributes.value
    @flow = params["flow"]

    if session[:ory_session_token]
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

  def check_email
    return render json: { success: false, message: t('errors.invalid_email') }, status: 200 if is_invalid_email(params[:email])

    phone = Phonelib.parse(params[:phone])
    return render json: { success: false, message: t('errors.invalid_phone') }, status: 200 unless (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile) or phone.types.include?(:fixed_line))

    return render json: { success: true }, status: 200
  rescue => e
    puts e
    return render status: 500
  end

  def post_registration
    session_identity = whoami

    if session_identity
      redirect_to (ENV['ORY_URL'] || '') + '/self-service/registration/browser' and return if session_identity == "Unauthorized"

      session[:ory_identity] = session_identity.identity
      session[:ory_session_token] = cookies["ory_session_" + ENV['ORY_SDK_KETO_URL'].split('//')[1].split('.')[0].gsub('-', '')]

      email = session[:ory_identity].traits[:email]
      id = session[:ory_identity].id
      language = session[:ory_identity].traits[:language]
      phone_number = Phonelib.parse(session_identity.identity.traits[:phone]).e164
      phone_number = phone_number.gsub('+', '')
      Client.create({
                      :email => email,
                      :first_name => session[:ory_identity].traits[:firstName],
                      :last_name => session[:ory_identity].traits[:lastName],
                      :phone => phone_number,
                      :preferred_locale => language,
                      :language => language,
                      :sign_in_count => 1,
                      :ory_id => id,
                      :country => session[:client_form][:country],
                      :time_zone => session[:client_form][:time_zone],
                      :phone_country => session[:client_form][:phone_country],
                      :country_code => session[:client_form][:country_code],
                      :receive_email => session[:client_form][:receive_email] == "true" ? true : false
                    }) unless Client.find_by_email(email)
    end

    redirect_to root_path
  rescue OryClient::ApiError => e
    puts "************ ory register error **********"
    puts e
    redirect_to root_path
  end

  def post_logout
    session.clear

    redirect_to root_path
  end
end
