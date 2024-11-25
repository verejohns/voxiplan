class AgendaAppsController < ApplicationController
  include ApplicationHelper

  before_action :check_ory_session

  def save_mobminder
    agenda_app = params[:agenda_id].blank? ? current_client.create_agenda : AgendaApp.find(params[:agenda_id])
    cur_agenda_type = agenda_app.type
    cur_mm_login = agenda_app.mm_login
    cur_mm_pwd = agenda_app.mm_pwd
    cur_mm_kid = agenda_app.mm_kid
    new_agenda_type = agenda_app.type == 'Mobminder' ? 'ClassicAgenda' : 'Mobminder'

    if new_agenda_type == 'Mobminder'
      agenda_app.update_attributes(
        type: new_agenda_type,
        mm_login: params[:agenda_app][:mm_login],
        mm_pwd: params[:agenda_app][:mm_pwd],
        mm_kid: params[:agenda_app][:mm_kid],
      )
      new_agenda_app = AgendaApp.find(agenda_app.id)
      if new_agenda_app.is_connected?
        message = t('select_agenda.mobminder.connect_success')
        response_type = 'success'

        new_agenda_app.services.each do |service|
          current_client.ivrs.each do |ivr|
            if Service.where(ivr_id: ivr.id, eid: service['id'], name: service['name'], ename: service['name']).count.zero?
              new_service = Service.new(ivr_id: ivr.id, eid: service['id'], name: service['name'], ename: service['name'], client_id: current_client.id,
                                        agenda_type: new_agenda_app.type, duration: 30, enabled: true,
                                        preference: {"pre_confirmation"=>"false", "enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"true", "sms_enabled"=>"true", "ai_phone_assistant_enabled"=>"false"})
              new_service.save

              resource_ids = []
              new_agenda_app.resources(service_id: service['id']).each do |resource|
                existed_resource = Resource.where(ivr_id: ivr.id, eid: resource['id'], name: resource['name'], ename: resource['name'])
                if existed_resource.count.zero?
                  new_resource = Resource.new(ivr_id: ivr.id, eid: resource['id'], name: resource['name'], ename: resource['name'], client_id: current_client.id,
                                              agenda_type: new_agenda_app.type, enabled: true)
                  new_resource.save
                  resource_ids.push(new_resource.id)
                else
                  resource_ids.push(existed_resource.first.id)
                end
              end
              new_service.resource_ids = resource_ids unless resource_ids.count.zero?
            end
          end
        end

      else
        agenda_app.update_attributes(
          type: cur_agenda_type,
          mm_login: cur_mm_login,
          mm_pwd: cur_mm_pwd,
          mm_kid: cur_mm_kid
        )
        message = t('select_agenda.connect_failure')
        response_type = 'error'
      end

    else
      current_client.ivrs.each do |ivr|
        ivr.services.where(agenda_type: 'Mobminder').each do |service|
          service.destroy
        end
        ivr.resources.where(agenda_type: 'Mobminder').each do |resource|
          resource.destroy
        end
      end
      agenda_app.destroy

      current_client.customers.each do |customer|
        customer.eid = customer.id
        customer.save
      end
      message = t('select_agenda.mobminder.disconnect_success')
      response_type = 'success'
    end

    return render json: {result: 'ok', type: response_type, agenda_id: agenda_app.id, message: message}, status: 200
  rescue => e
    puts e
    agenda_app.update_attributes(
      type: cur_agenda_type,
      mm_login: cur_mm_login,
      mm_pwd: cur_mm_pwd,
      mm_kid: cur_mm_kid
    )
    return render json: {type: 'error', message: e.message}
  end

  def save_timify
    agenda_app = params[:agenda_id].blank? ? current_client.create_agenda : AgendaApp.find(params[:agenda_id])
    cur_agenda_type = agenda_app.type
    cur_company_id = agenda_app.timify_company_id
    new_agenda_type = cur_agenda_type == 'Timify' ? 'ClassicAgenda' : 'Timify'

    if new_agenda_type == 'Timify'
      agenda_app.update_attributes(
        type: new_agenda_type,
        timify_company_id: params[:agenda_app][:timify_company_id],
      )
      new_agenda_app = AgendaApp.find(agenda_app.id)
      if new_agenda_app.is_connected?
        message = t('select_agenda.timify.connect_success')
        response_type = 'success'

        new_agenda_app.services.each do |service|
          current_client.ivrs.each do |ivr|
            if Service.where(ivr_id: ivr.id, eid: service['id'], name: service['name'], ename: service['name']).count.zero?
              new_service = Service.new(ivr_id: ivr.id, eid: service['id'], name: service['name'], ename: service['name'], client_id: current_client.id,
                                        agenda_type: new_agenda_app.type, duration: 30, enabled: true,
                                        preference: {"pre_confirmation"=>"false", "enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"true", "sms_enabled"=>"true", "ai_phone_assistant_enabled"=>"false"})
              new_service.save

              resource_ids = []
              new_agenda_app.resources(service_id: service['id']).each do |resource|
                existed_resource = Resource.where(ivr_id: ivr.id, eid: resource['id'], name: resource['name'], ename: resource['name'])
                if existed_resource.count.zero?
                  new_resource = Resource.new(ivr_id: ivr.id, eid: resource['id'], name: resource['name'], ename: resource['name'], client_id: current_client.id,
                                              agenda_type: new_agenda_app.type, enabled: true)
                  new_resource.save
                  resource_ids.push(new_resource.id)
                else
                  resource_ids.push(existed_resource.first.id)
                end
              end
              new_service.resource_ids = resource_ids unless resource_ids.count.zero?

            end
          end
        end

      else
        agenda_app.update_attributes(
          type: cur_agenda_type,
          timify_company_id: cur_company_id
        )
        message = t('select_agenda.connect_failure')
        response_type = 'error'
      end
    else
      current_client.ivrs.each do |ivr|
        ivr.services.where(agenda_type: 'Timify').each do |service|
          service.destroy
        end
        ivr.resources.where(agenda_type: 'Timify').each do |resource|
          resource.destroy
        end
      end

      agenda_app.destroy

      current_client.customers.each do |customer|
        customer.eid = customer.id
        customer.save
      end

      message = t('select_agenda.timify.disconnect_success')
      response_type = 'success'
    end

    return render json: {result: 'ok', type: response_type, agenda_id: agenda_app.id, message: message}, status: 200
  rescue => e
    puts e
    agenda_app.update_attributes(
      type: cur_agenda_type,
      timify_company_id: cur_company_id
    )
    return render json: {type: 'error', message: e.message}
  end

  def save_agenda_info_old
    agenda = AgendaApp.find_by(id: params[:agenda_id])
    if agenda
      agenda.update_attributes(
        type: 'ClassicAgenda',
        client_id: current_client.id,
        cronofy_access_token: params['cronofy_access_token'],
        cronofy_refresh_token: params['cronofy_refresh_token'],
        cronofy_profile_id: params['cronofy_profile_id'],
        cronofy_profile_name: params['cronofy_profile_name'],
        cronofy_provider_name: params['cronofy_provider_name'],
        cronofy_account_id: params['cronofy_account_id'],
      # default_resource_availability: available_hours
        )

      agenda = AgendaApp.find_by(id: params[:agenda_id]) # get agenda again for classic agenda

      unless agenda.cronofy_access_token.blank?
        channel = agenda.create_channel(notification_callback_url(current_client.id))
        calendar_id = agenda.all_calendars.first[1]
        calendar_account = agenda.all_calendars.first[0]
        agenda.update(default_resource_calendar: calendar_id)
        agenda.update_attributes(calendar_id: calendar_id, calendar_account: calendar_account, conflict_calendars: calendar_id, channel_id: channel[:channel_id])

        current_client.ivrs.each do |ivr|
          default_resources = ivr.resources.where("calendar_type = ? and my_calendar_type = ? and client_id = ?", "my_calendar", "default", current_client.id)
          default_resources.update_all(conflict_calendars: calendar_id, calendar_id: calendar_id)
        end
      end

      current_client.customers.each do |customer|
        agenda_customer = agenda.find_customer(phone: customer.phone_number, client_id: current_client.id) if customer.phone_number
        customer.update(eid: agenda_customer.id) if agenda_customer
      end
    end

    current_client.update_columns(sign_in_count: current_client.sign_in_count + 1, server_region: params['server_region'], is_welcomed: true)
    current_client.ivrs.each do |ivr|
      ivr.update_columns(booking_url: ivr.uid)
    end

    redirect_to root_path
  end

  def save_agenda_info
    # availabilities
    availability_hours = availabilities_hours(params[:business_hours])
    override_hours = override_hours(params[:override_hours])
    current_client.services.each do |service|
      service.use_default_availability = false
      service.schedule_template_id = 0
      service.availability = availability_hours.to_json
      service.overrides = override_hours.empty? ? nil : override_hours

      service_dup = Service.where(eid: service.id, agenda_type: 'ClassicAgenda').first
      if service_dup
        service_dup.use_default_availability = service.use_default_availability
        service_dup.schedule_template_id = service.schedule_template_id
        service_dup.availability = availability_hours.to_json
        service_dup.overrides = override_hours.empty? ? nil : override_hours
        service_dup.client_id = current_client.id
        service_dup.save
        Service.where(id: service_dup.id).update_all(client_id: nil)
      end
      service.save
    end

    current_client.resources.each do |resource|
      resource.use_default_availability = false
      resource.schedule_template_id = 0
      resource.availability = availability_hours
      resource.overrides = override_hours.empty? ? nil : override_hours

      resource_dup = Resource.where(eid: resource.id, agenda_type: 'ClassicAgenda').first
      if resource_dup
        resource_dup.use_default_availability = resource.use_default_availability
        resource_dup.schedule_template_id = resource.schedule_template_id
        resource_dup.availability = availability_hours
        resource_dup.overrides = override_hours.empty? ? nil : override_hours
        resource_dup.client_id = current_client.id
        resource_dup.save
        Resource.where(id: resource_dup.id).update_all(client_id: nil)
      end
      resource.save
    end

    # Update organization name
    if !params[:organization_name].nil? && params[:organization_name] != ''
      my_organization = current_client.organizations.first if current_client
      my_organization.update_columns(name: params[:organization_name]) if my_organization
    end

    # update ivr voxiplan url text
    if !params[:voxiplan_url].nil? && params[:voxiplan_url] != ''
      current_client.ivrs.first.update_columns(booking_url: params[:voxiplan_url].downcase)
    end

    agenda = AgendaApp.find_by(id: params[:agenda_id])
    if agenda
      agenda.update_attributes(
        type: 'ClassicAgenda',
        client_id: current_client.id,
        cronofy_access_token: params['cronofy_access_token'],
        cronofy_refresh_token: params['cronofy_refresh_token'],
        cronofy_profile_id: params['cronofy_profile_id'],
        cronofy_profile_name: params['cronofy_profile_name'],
        cronofy_provider_name: params['cronofy_provider_name'],
        cronofy_account_id: params['cronofy_account_id'],
      # default_resource_availability: available_hours
        )

      agenda = AgendaApp.find_by(id: params[:agenda_id]) # get agenda again for classic agenda

      unless agenda.cronofy_access_token.blank?
        channel = agenda.create_channel(notification_callback_url(current_client.id))
        calendar_id = agenda.all_calendars.first[1]
        calendar_account = agenda.all_calendars.first[0]
        agenda.update(default_resource_calendar: calendar_id)
        agenda.update_attributes(calendar_id: calendar_id, calendar_account: calendar_account, conflict_calendars: calendar_id, channel_id: channel[:channel_id])
        # agenda.update_attributes(calendar_id: calendar_id, calendar_account: calendar_account, conflict_calendars: calendar_id)

        current_client.ivrs.each do |ivr|
          ivr.resources.update_all(conflict_calendars: calendar_id, calendar_id: calendar_id)
        end
      end

      current_client.customers.each do |customer|
        agenda_customer = agenda.find_customer(phone: customer.phone_number, client_id: current_client.id) if customer.phone_number
        customer.update(eid: agenda_customer.id) if agenda_customer
      end
    end

    current_client.update_columns(server_region: 'DE', sign_in_count: current_client.sign_in_count + 1, time_zone: params[:timezone], is_welcomed: true)

    render json: {message: 'Your agenda has been successfully created!', redirect_url: services_path}, status: 200
  end

  def save_voxiplan_url
    my_organization = Organization.where("client_id = ?", current_client.id).first if current_client
    my_organization.update_columns(name: params[:organization_name]) if params[:organization_name]

    current_client.ivrs.first.update_columns(booking_url: params[:voxiplan_url].downcase) if params[:voxiplan_url]

    return render json: { success: true }, status: 200
  rescue => e
    puts e
    return render status: 500
  end

  def create_new_agenda
    session[:cronofy_auth_success_callback_url] = request.env['HTTP_REFERER']
    cronofy_locales = ['cs', 'cy', 'de', 'en', 'es', 'fr', 'fr-CA', 'it', 'ja', 'nl', 'pl', 'pt-BR', 'ru', 'sv', 'tr']
    locale = cronofy_locales.include?(params[:browser_locale]) ? params[:browser_locale] : 'en'

    cronofy = current_client.create_cronofy
    authorization_url = cronofy.user_auth_link(cronofy_auth_callback_url)
    render json: {cronofy_auth_url: authorization_url, user_locale: locale}, status: 200
  end

  def get_calendars_of_agenda
    calendar_account = params[:calendar_account]
    selected_agenda = AgendaApp.where(cronofy_profile_name: calendar_account, client_id: current_client.id).first
    render json: {calendars: selected_agenda ? selected_agenda.all_calendars : []}
  end

  private

  def agenda_attributes
    params.require(:agenda_app).permit(:id, :type, :ss_schedule_id, :ss_checksum,:ss_default_params, :mm_login, :mm_pwd, :mm_kid, :default_resource_calendar)
  end

end
