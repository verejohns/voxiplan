class IntegrationsController < ApplicationController
  include IvrsHelper
  include NodeUtils
  include PhoneNumberUtils
  include ApplicationHelper

  layout 'layout'
  before_action :check_ory_session

  def select_agenda
    @first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
    @subscription_plan = session[:current_organization].chargebee_subscription_plan
    @subscription_plan ||= 'free'
  end

  def select_mobminder
    @first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
  end

  def select_timify
    @first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
  end

  def connect_your_agenda
    agenda_id = params[:agenda_id]
    access_token = params[:access_token]
    refresh_token = params[:refresh_token]
    if params[:success] && agenda_id && access_token && refresh_token
      agenda_list = AgendaApp.where(client_id: current_client.id, cronofy_provider_name: params[:provider_name], cronofy_profile_name: params[:profile_name])
      agenda = AgendaApp.find_by(id: agenda_id)
      unless agenda_list.count.zero?
        # if exist the agenda that has same provider name, will delete it.
        agenda.destroy
      else
        agenda.update_attributes(
          type: 'ClassicAgenda',
          cronofy_access_token: access_token,
          cronofy_refresh_token: refresh_token,
          cronofy_profile_id: params[:profile_id],
          cronofy_profile_name: params[:profile_name],
          cronofy_provider_name: params[:provider_name],
          cronofy_account_id: params[:account_id],
          organization_id: session[:current_organization].id
        )
        agenda = AgendaApp.find_by(id: agenda_id) # get agenda again for classic agenda
        unless agenda.cronofy_access_token.blank?
          channel = agenda.create_channel(notification_callback_url(current_client.id))
          agenda.update_attributes(channel_id: channel[:channel_id])

          calendar_id = agenda.all_calendars.first[1]
          calendar_account = agenda.all_calendars.first[0]
          if current_client.agenda_apps.where("type = ? AND calendar_account IS NOT NULL", "ClassicAgenda").count.zero?
            agenda.update_attributes(calendar_id: calendar_id, calendar_account: calendar_account)
          end
          agenda.update_attributes(conflict_calendars: calendar_id)

          new_conflict_calendars = ""
          current_client.ivrs.each do |ivr|
            # set default calendar and "conflict calendars" of resource
            default_resouorces = ivr.resources.where(calendar_type: "my_calendar", my_calendar_type: "default", client_id: current_client.id)

            unless default_resouorces.count.zero?
              old_conflict_calendars = default_resouorces[0].conflict_calendars

              if old_conflict_calendars.nil? || old_conflict_calendars.blank?
                new_conflict_calendars = old_conflict_calendars
              else
                new_conflict_calendars = old_conflict_calendars + "," + calendar_id
              end
              default_resouorces.update_all(calendar_id: calendar_id) if current_client.agenda_apps.where(type: "ClassicAgenda").count == 1
              default_resouorces.update_all(conflict_calendars: new_conflict_calendars)
            end
          end

          member_resources = Resource.where(calendar_type: "team_calendar", team_calendar_client_id: current_client.id)
          member_resources.each do |resource|
            resource.update_columns(calendar_id: calendar_id) if current_client.agenda_apps.where(type: "ClassicAgenda").count == 1
            resource.update_columns(conflict_calendars: new_conflict_calendars)
          end
        end

        current_client.ivrs.each do |ivr|
          ivr.client.customers.each do |customer|
            agenda_customer = agenda.find_customer(phone: customer.phone_number, client_id: current_client.id) if customer.phone_number
            customer.update(eid: agenda_customer.id) if agenda_customer
          end
        end
      end

      redirect_to connect_your_agenda_integrations_path
    end

    @browser_locale = get_browser_locale.to_s
    @agenda_icon = { 'google' => {'icon' => 'google-calendar.svg', 'name' => t('onboarding.connect_calendar.google'), 'detail' => t('onboarding.connect_calendar.google_detail')},
                     'live_connect' => {'icon' => 'outlook-plug-in.svg', 'name' => t('onboarding.connect_calendar.outlook'), 'detail' => t('onboarding.connect_calendar.outlook_detail')},
                     'exchange' => {'icon' => 'exchange-calendar.svg', 'name' => t('onboarding.connect_calendar.exchange'), 'detail' => t('onboarding.connect_calendar.exchange_detail')},
                     'office365' => {'icon' => 'office-365-calendar.svg', 'name' => t('onboarding.connect_calendar.office_365'), 'detail' => t('onboarding.connect_calendar.office_365_detail')},
                     'apple' => {'icon' => 'icloud-calendar.svg', 'name' => t('onboarding.connect_calendar.icloud'), 'detail' => t('onboarding.connect_calendar.icloud_detail')}}
    @cronofy_redirect_url = "#{request.protocol}#{request.host_with_port}/auth/cronofy"

    @agenda_apps = current_client.agenda_apps
    classic_agenda = current_client.agenda_apps.where(type: 'ClassicAgenda')
    @added_agenda = classic_agenda.count.zero? ? @agenda_apps.count.zero? ? nil : @agenda_apps.first : classic_agenda.where('calendar_id IS NOT NULL').first

    @is_support_cronofy = false
    @agenda_apps.each do |agenda_app|
      @is_support_cronofy = true unless agenda_app.cronofy_provider_name.nil? || agenda_app.cronofy_provider_name.blank?
    end

    @server_regions = {'US': 'US', 'DE': 'EU', 'UK': 'GB', 'CA': 'CA', 'AU': 'AU', 'SG': 'SG'}
    @selected_server_region = current_client.server_region

    @application_calendars = []
    application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id )
    application_calendars.each do |application_calendar|
      @application_calendars.push({
        name: application_calendar.name,
        cronofy_profile_name: application_calendar.name,
        conflict_calendars: application_calendar.conflict_calendars,
        cronofy_provider_name: 'application',
        calendar_name: application_calendar.calendar_name,
        calendar_id: application_calendar.calendar_id
      })
    end
    @added_application_calendar = @application_calendars.count.zero? ? nil : @application_calendars[0]

    @calendar_enabled = true
    unless checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "owner", "client-" + current_client.id.to_s)
      invitation = Invitation.where(organization_id: session[:current_organization].id, to_email: current_client.email).first
      @calendar_enabled = invitation.enable_calendar if invitation
    end

    @external_calendars = session[:current_organization].agenda_apps
    @application_calendars_all = ApplicationCalendar.where(organization_id: session[:current_organization].id)
  end

  def disconnect_calendar
    agenda = AgendaApp.find_by(id: params[:agenda_id])

    if agenda
      if AgendaApp.where(cronofy_refresh_token: agenda.cronofy_refresh_token).count == 1
        agenda.close_channel(agenda.channel_id)
        data_center = current_client.data_server
        query = {
          'client_id'     => ENV["CRONOFY_#{data_center}_CLIENT_ID"],
          'client_secret' => ENV["CRONOFY_#{data_center}_CLIENT_SECRET"],
          'token'         => agenda.cronofy_refresh_token,
          'data_center'   => data_center.downcase
        }
        headers = {'Content-Type'  => 'application/json'}

        HTTParty.post(
          helpers.get_api_center_url(data_center.downcase) + "/oauth/token/revoke",
          :query => query,
          :headers => headers
        )
      end

      default_resouorces = current_client.resources.where(calendar_type: "my_calendar", my_calendar_type: "default", client_id: current_client.id)

      calendar_id = ""
      unless agenda.calendar_id.nil? || agenda.calendar_id.blank?
        agenda_apps = current_client.agenda_apps.where("type = ? AND id != ?", "ClassicAgenda", agenda.id)
        if agenda_apps.count.zero?
          application_calendar = ApplicationCalendar.where(client_id: current_client.id, organization_id: session[:current_organization].id).first
          calendar_id = application_calendar.calendar_id unless application_calendar.nil?
          default_resouorces.update_all(calendar_id: calendar_id)
        else
          calendar_id = agenda_apps[0].conflict_calendars
          agenda_apps[0].update_attributes(calendar_id: calendar_id, calendar_account: agenda_apps[0].cronofy_profile_name)
          default_resouorces.update_all(calendar_id: calendar_id)
        end
      end

      conflict_calendars = ""
      unless agenda.conflict_calendars.nil?
        unless default_resouorces.count.zero?
          conflict_calendars = default_resouorces[0].conflict_calendars
          if conflict_calendars.index(agenda.conflict_calendars) != nil
            if conflict_calendars.index(agenda.conflict_calendars).positive?
              conflict_calendars.slice! "," + agenda.conflict_calendars
            else
              conflict_calendars.slice! agenda.conflict_calendars + ","
            end

            default_resouorces.update_all(conflict_calendars: conflict_calendars)
          end
        end
      end
      agenda.destroy

      member_resources = Resource.where(calendar_type: "team_calendar", team_calendar_client_id: current_client.id)
      member_resources.each do |resource|
        resource.update_columns(conflict_calendars: conflict_calendars, calendar_id: calendar_id)
      end
    end
    redirect_to connect_your_agenda_integrations_path
  end

  def update_calendar
    current_client.agenda_apps.where("type = ?", "ClassicAgenda").update_all(calendar_account: nil, calendar_id: nil)

    calendar_account = params[:calendar_account]
    calendar_id = ""
    if calendar_account == "none"
      ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id, calendar_id: params[:selected_calendar_account]).update_all(calendar_id: nil)
      current_client.agenda_apps.where("type = ?", "ClassicAgenda").update_all(calendar_id: nil, calendar_account: nil)
      current_client.resources.where("calendar_type = ? and my_calendar_type = ? and client_id IS NOT NULL", "my_calendar", "default").update_all(calendar_id: nil)
    elsif calendar_account["cronofy_calendar_"]
      application_calendar = ApplicationCalendar.find(params[:calendar_account].split('cronofy_calendar_')[1])

      current_client.ivrs.each do |ivr|
        ivr.resources.where("calendar_type = ? and my_calendar_type = ? and client_id IS NOT NULL", "my_calendar", "default").update_all(
          calendar_id: application_calendar.calendar_id,
          # conflict_calendars: application_calendar.conflict_calendars,
          application_calendar_id: application_calendar.calendar_id,
          application_access_token: application_calendar.access_token,
          application_refresh_token: application_calendar.refresh_token,
          application_sub: application_calendar.application_sub
        )
      end
      calendar_id = application_calendar.calendar_id
    else
      agenda = current_client.agenda_apps.find_by(cronofy_profile_name: params[:calendar_account])
      if agenda
        agenda.update_attributes(
          calendar_id: params[:calendar_id],
          calendar_account: calendar_account
        )

        current_client.ivrs.each do |ivr|
          ivr.resources.where("calendar_type = ? and my_calendar_type = ? and client_id IS NOT NULL", "my_calendar", "default").update_all(
            calendar_id: params[:calendar_id],
            # conflict_calendars: agenda.conflict_calendars,
            application_calendar_id: agenda.calendar_id,
            application_access_token: agenda.cronofy_access_token,
            application_refresh_token: agenda.cronofy_refresh_token,
          # application_sub: agenda.cronofy_account_id
            )
        end
        calendar_id = params[:calendar_id]
      end
    end

    member_resources = Resource.where(calendar_type: "team_calendar", team_calendar_client_id: current_client.id)
    member_resources.each do |resource|
      resource.update_columns(calendar_id: calendar_id)
    end

    redirect_to connect_your_agenda_integrations_path
  end

  def update_conflict
    selected_calendar_account = params[:selected_calendar_account]
    selected_conflict_calendar = params[:conflict_calendar]
    conflict_calendars = selected_conflict_calendar.blank? ? nil : selected_conflict_calendar.join(',')

    if params[:calendar_type] == 'application'
      application_calendar = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id, calendar_id: params[:selected_calendar_account])
      old_conflict_calendar = application_calendar[0].conflict_calendars
      application_calendar.update_all(conflict_calendars: conflict_calendars)
    else
      selected_agenda = current_client.agenda_apps.find_by(cronofy_profile_name: selected_calendar_account)
      old_conflict_calendar = selected_agenda.conflict_calendars
      selected_agenda.update_attributes(conflict_calendars: conflict_calendars)
    end

    new_conflict_calendars = conflict_calendars
    current_client.ivrs.each do |ivr|
      default_resources = ivr.resources.where("calendar_type = ? and my_calendar_type = ? and client_id = ?", "my_calendar", "default", current_client.id)
      old_conflict_calendars = default_resources[0].conflict_calendars

      if old_conflict_calendar
        if old_conflict_calendars.index(old_conflict_calendar) && old_conflict_calendars.index(old_conflict_calendar) > 0
          old_conflict_calendars.slice! "," + old_conflict_calendar
        else
          old_conflict_calendars.slice! old_conflict_calendar + ","
        end
      end

      unless conflict_calendars == nil || conflict_calendars == ''
        old_conflict_calendars = old_conflict_calendars + ',' + conflict_calendars
      end

      default_resources.update_all(conflict_calendars: old_conflict_calendars)
      new_conflict_calendars = old_conflict_calendars
    end

    member_resources = Resource.where(calendar_type: "team_calendar", team_calendar_client_id: current_client.id)
    member_resources.each do |resource|
      resource.update_columns(conflict_calendars: new_conflict_calendars)
    end

    redirect_to connect_your_agenda_integrations_path
  end

  def change_dataserver
    org_server_region = current_client.server_region
    new_server_region = params[:server_region]

    current_client.agenda_apps.where(type: 'ClassicAgenda').each do |agenda|
      agenda.close_channel(agenda.channel_id)
      query = {'client_id' => ENV["CRONOFY_#{org_server_region}_CLIENT_ID"], 'client_secret' => ENV["CRONOFY_#{org_server_region}_CLIENT_SECRET"], 'token' => agenda.cronofy_refresh_token}
      headers = {'Content-Type'  => 'application/json'}
      response = HTTParty.post(helpers.get_api_center_url(org_server_region) + "/oauth/token/revoke", :query => query, :headers => headers)
      if response.code == 200
        current_client.resources.where(calendar_id: agenda.calendar_id).update_all(calendar_id: nil)
        agenda.destroy
      end
    end

    current_client.ivrs.each do |ivr|
      ivr.resources.where("application_refresh_token IS NOT NULL").each do |resource|
        org_resouce_refresh_token = resource.application_refresh_token

        # connect to new region
        application_calendar_id = 'cronofy_calendar_' + resource.id.to_s
        cronofy = current_client.create_cronofy(server_region: new_server_region)
        application_calendar = cronofy.application_calendar(application_calendar_id)

        cronofy = current_client.create_cronofy(server_region: new_server_region, access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
        calendars = cronofy.list_calendars
        created_calendar = calendars.select{|c| c.calendar_name == application_calendar_id}

        resource.update_attributes(
          application_calendar_id: created_calendar[0].calendar_id,
          application_access_token: application_calendar.access_token,
          application_refresh_token: application_calendar.refresh_token,
          application_sub: application_calendar.sub,
          )
        current_client.update_columns(server_region: new_server_region)

        # disconnect from org region
        query = {'client_id' => ENV["CRONOFY_#{org_server_region}_CLIENT_ID"], 'client_secret' => ENV["CRONOFY_#{org_server_region}_CLIENT_SECRET"], 'token' => org_resouce_refresh_token}
        headers = {'Content-Type'  => 'application/json'}
        HTTParty.post(helpers.get_api_center_url(org_server_region) + "/oauth/token/revoke", :query => query, :headers => headers)
      end
    end

    render json: {result: 'success', message: t('common.save_success')}
  rescue Exception => e
    render json: {result: 'error', message: e.message}
  end

  def index
    @subscription_plan = session[:current_organization].chargebee_subscription_plan
    @subscription_plan ||= 'free'
  end

  def phone
    @phone_numbers = []
    incoming_phone_numbers = twilioclient.incoming_phone_numbers.list
    current_client.ivrs.each do |ivr|
      identifers = ivr.identifiers.pluck(:identifier).map{|i| "+#{i}" if i.scan(/\D/).empty?}.compact
      phone_number = PhoneNumber.where(number: identifers).order(id: :asc)

      phone_number.each do |phone_number_item|

        incoming_phone_numbers.each do |incoming_phone_number|
          if incoming_phone_number.phone_number == phone_number_item.number
            inbound_sms = incoming_phone_number.sms_url.nil? || incoming_phone_number.sms_url == ''
            @phone_numbers.push({
                                  id: phone_number_item.id,
                                  number: phone_number_item.number,
                                  friendly_name: phone_number_item.friendly_name,
                                  sms: phone_number_item.sms,
                                  voice: phone_number_item.voice,
                                  client_id: phone_number_item.client_id,
                                  phone_type: phone_number_item.phone_type,
                                  inbound_sms: !inbound_sms
                                })
            break
          end
        end
      end
    end

    if request.post?
      phone_number = PhoneNumber.find_by_id params["id"]
      phone_number.friendly_name = params["name"]
      phone_number.client_id = current_client.id

      if phone_number.save
        render json: {result: 'success', message: t('common.save_success')}
      else
        render json: {result: 'error', message: phone_number.errors.full_messages }
      end
    end
  end

  def inbound_sms
    incoming_phone_numbers = twilioclient.incoming_phone_numbers.list

    phone_number = PhoneNumber.find(params[:id])
    inbound_sms = false

    incoming_phone_numbers.each do |incoming_phone_number|
      if phone_number.number == incoming_phone_number.phone_number
        sid = incoming_phone_number.sid
        inbound_sms = incoming_phone_number.sms_url.nil? || incoming_phone_number.sms_url == ''

        if inbound_sms
          incoming_phone_number_new = twilioclient.incoming_phone_numbers(sid).update(sms_url: 'https://app.voxiplan.com/sms')
        else
          incoming_phone_number_new = twilioclient.incoming_phone_numbers(sid).update(sms_url: '', sms_fallback_url: '')
        end
        puts incoming_phone_number_new

        break
      end
    end

    render json: {result: 'success', message: inbound_sms ? t('integrations.phone_number.enabled_inbound_sms') : t('integrations.phone_number.disabled_inbound_sms')}
  rescue => e
    puts e
    render json: {result: 'error', message: t('errors.something_wrong')}
  end

  def sms
    @first_ivr = current_client.ivrs.order('id').first
    identifiers = @first_ivr.identifiers.pluck(:identifier).map{|i| "+#{i}" if i.scan(/\D/).empty?}.compact
    @country_code = current_client.country_code
    @alpha_from = @first_ivr.preference['sms_from']
    @phone_numbers = PhoneNumber.where(number: identifiers, sms: true)
    if request.post?
      selected_ivr = current_client.ivrs.find(params[:selected_ivr])
      selected_ivr.preference['sms_from'] = params["phone_value"] == "-" ? "" : params["phone_value"] # e164 with +
      selected_ivr.preference["sms_engin"] = params["preference"]["sms_engin"]
      # Default CustomerId is same as phone in e164 without +
      # we can change from admin panel
      if params["preference"]["sms_engin"] == "voxi_sms"
        selected_ivr.preference['voxi_sms_customer_id'] = voxi_phone(params["phone_value"])
        selected_ivr.preference["voxi_sms_secret"] = params["secret"]
      end
      save_result = selected_ivr.save

      if save_result
        render json: {result: 'success', message: t('common.save_success')}
      else
        render json: {result: 'error', message: t('common.save_failure')}
      end
    end
  end

  def get_sms_channel
    selected_ivr = Ivr.find(params[:selected_ivr])
    identifiers = selected_ivr.identifiers.pluck(:identifier).map{|i| "+#{i}" if i.scan(/\D/).empty?}.compact
    alpha_from = selected_ivr.preference['sms_from']
    alpha_from = (alpha_from&.match?("^(?![0-9]+$)[a-zA-Z0-9 ]{2,}$") && alpha_from.match("[a-zA-Z]")) ? alpha_from : ''
    phone_numbers = PhoneNumber.where(number: identifiers, sms: true)
    render json: { result: 'success', ivr_preference: selected_ivr.preference, alpha_from: alpha_from, phone_numbers: phone_numbers }
  rescue => e
    render json: { result: 'error', message: e.message}
  end

  def alpha_sms
    if request.post?
      selected_ivr = Ivr.find(params[:selected_ivr])
      selected_ivr.preference['sms_from'] = params["alpha_from"]
      if selected_ivr.save
        render json: {result: 'success', message: t('common.save_success')}
      else
        render json: {result: 'error', message: t('common.save_failure')}
      end
    end
  end

  private

  def agenda_attributes
    params.require(:agenda_app).permit(:default_resource_calendar)
  end
end
