class ResourcesController < ApplicationController
  include ApplicationHelper

  before_action :check_ory_session
  before_action :set_resource, only: %i[index update toggle_enabled]
  before_action :set_first_agenda, only: %i[create]

  layout 'layout'

  def index; end

  def edit
    @resource = Resource.find_by(id: params[:id])
    @resource_customize_availability = @resource.availability
    @resource_customize_overrides = @resource.overrides
    if @resource.schedule_template_id.zero?
      # if client user 'customize hours', schedule template is default template.
      @selected_resource_schedule = current_client.schedule_templates.where(is_default: true).first
      @selected_availability_type = 'customize'
    else
      # if client user 'default hours', schedule template is selected template.
      @selected_resource_schedule = current_client.schedule_templates.find(@resource.schedule_template_id)
      @selected_availability_type = 'default'
    end
    @selected_resource_schedule_id = @selected_resource_schedule.id


    render 'services/resource_show', layout: false, status: 200
  end

  def create
    service = Service.find_by(id: params[:current_service_id])
    cur_ivr = Ivr.find(service.ivr_id)

    resource = Resource.new(name: params[:resource_name].blank? ? params[:resource_ename] : params[:resource_name], ename: params[:resource_ename], client: current_client, ivr: cur_ivr)
    default_schedule = current_client.schedule_templates.where(is_default: true).first
    resource.schedule_template_id = default_schedule.id
    resource.availability = default_schedule.availability.availabilities
    resource.overrides = default_schedule.availability.overrides
    resource.is_default = false
    resource.calendar_type = 'my_calendar'
    resource.my_calendar_type = 'default'
    if resource.save
      added_calendar_id = nil
      conflict_calendar_ids = []
      application_id = nil
      application_access_token = nil
      application_refresh_token = nil
      application_sub = nil

      application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id )
      application_calendars.each do |application_calendar|
        added_calendar_id = application_calendar.calendar_id unless application_calendar.calendar_id.nil?
        conflict_calendar_ids.push(application_calendar.conflict_calendars) unless application_calendar.conflict_calendars.nil?
        application_id = application_calendar.calendar_id unless application_calendar.calendar_id.nil?
        application_access_token = application_calendar.access_token unless application_calendar.access_token.nil?
        application_refresh_token = application_calendar.refresh_token unless application_calendar.refresh_token.nil?
        application_sub = application_calendar.application_sub unless application_calendar.application_sub.nil?
      end

      current_client.agenda_apps.each do |agenda|
        added_calendar_id = agenda.calendar_id unless agenda.calendar_id.nil?
        conflict_calendar_ids.push(agenda.conflict_calendars) unless agenda.conflict_calendars.nil?
        application_id = agenda.calendar_id unless agenda.calendar_id.nil?
        application_access_token = agenda.cronofy_access_token unless agenda.cronofy_access_token.nil?
        application_refresh_token = agenda.cronofy_refresh_token unless agenda.cronofy_refresh_token.nil?
        application_sub = agenda.cronofy_account_id unless agenda.cronofy_account_id.nil?
      end

      resource.update_attributes(
        calendar_id: added_calendar_id,
        conflict_calendars: conflict_calendar_ids.count.zero? ? nil : conflict_calendar_ids.join(','),
        application_calendar_id: application_id,
        application_access_token: application_access_token,
        application_refresh_token: application_refresh_token,
        application_sub: application_sub,
      )

      resource_dup = Resource.new(name: params[:resource_name].blank? ? params[:resource_ename] : params[:resource_name], ename: params[:resource_ename], client: current_client, ivr: cur_ivr)
      resource_dup.agenda_type = "ClassicAgenda"
      resource_dup.eid = resource.id
      resource_dup.schedule_template_id = default_schedule.id
      resource_dup.availability = default_schedule.availability.availabilities
      resource_dup.overrides = default_schedule.availability.overrides
      resource_dup.calendar_type = 'my_calendar'
      resource_dup.my_calendar_type = 'default'
      resource_dup.save
      Resource.where(id: resource_dup.id).update_all(client_id: nil)

      render json: {result: 'success', message: t('services.resources.created_success'), resource_id: resource.id, calendar_id: added_calendar_id}
    else
      render json: {result: 'error', message: t('services.resources.created_error') }
    end
  end

  def update_resource
    @resource = Resource.find(params[:selected_resource_id])
    resource_dup = Resource.where(eid: @resource.id, agenda_type: 'ClassicAgenda').first

    @resource.name = params[:resource_name].blank? ? params[:resource_ename] : params[:resource_name]
    @resource.ename = params[:resource_ename]
    resource_dup.name = @resource.name
    resource_dup.ename = @resource.ename

    calendar_type = params[:calendar_type]
    my_calendar_type = params[:my_calendar_type]
    @resource.calendar_type = calendar_type
    @resource.my_calendar_type = my_calendar_type
    @resource.team_calendar_client_id = params[:team_calendar]

    resource_availability_type = params[:resource_availability_category] if params[:resource_availability_category]
    if resource_availability_type == 'default'
      @resource.use_default_availability = true
      resource_schedule_template = current_client.schedule_templates.find(params[:resource_schedule_templates])
      @resource.schedule_template_id = resource_schedule_template.id
      @resource.availability = resource_schedule_template.availability.availabilities
      @resource.overrides = resource_schedule_template.availability.overrides ? resource_schedule_template.availability.overrides : nil

      if resource_dup
        resource_dup.use_default_availability = @resource.use_default_availability
        resource_dup.schedule_template_id = @resource.schedule_template_id
        resource_dup.availability = resource_schedule_template.availability.availabilities
        resource_dup.overrides = resource_schedule_template.availability.overrides ? resource_schedule_template.availability.overrides : nil
      end
    end

    if resource_availability_type == 'customize'
      @resource.use_default_availability = false
      @resource.schedule_template_id = 0
      resource_avaialbility_hours = availabilities_hours(params[:business_hours])
      resource_override_hours = override_hours(params[:override_hours])
      @resource.availability = resource_avaialbility_hours
      @resource.overrides = resource_override_hours.empty? ? nil : resource_override_hours

      if resource_dup
        resource_dup.use_default_availability = @resource.use_default_availability
        resource_dup.schedule_template_id = @resource.schedule_template_id
        resource_dup.availability = resource_avaialbility_hours
        resource_dup.overrides = resource_override_hours.empty? ? nil : resource_override_hours
      end
    end

    if calendar_type == 'app_calendar'
      @resource.calendar_id = nil
      @resource.conflict_calendars = nil
    end

    if calendar_type == 'my_calendar'
      if my_calendar_type == 'default'
        added_calendar_id = nil
        conflict_calendar_ids = []
        current_client.agenda_apps.each do |agenda_app|
          added_calendar_id = agenda_app.calendar_id unless agenda_app.calendar_id.nil?
          conflict_calendar_ids.push(agenda_app.conflict_calendars) unless agenda_app.conflict_calendars.nil?
        end

        if added_calendar_id.nil?
          added_calendar_id = params[:added_calendar_ids]
          conflict_calendar_ids = [params[:conflict_calendar_ids]]
        end

        @resource.calendar_id = added_calendar_id
        @resource.conflict_calendars = conflict_calendar_ids.count.zero? ? nil : conflict_calendar_ids.join(',')
      end

      if my_calendar_type == 'customize'
        @resource.calendar_id = params[:added_calendar_ids]
        @resource.conflict_calendars = params[:conflict_calendar_ids]
      end
    end

    if calendar_type == 'team_calendar'
      added_calendar_id = nil
      conflict_calendar_ids = []
      application_calendar_id = nil
      application_access_token = nil
      application_refresh_token = nil
      application_sub = nil

      member_client = Client.find(params[:team_calendar])
      member_application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: member_client.id )
      member_agendas = member_client.agenda_apps

      member_application_calendars.each do |application_calendar|
        added_calendar_id = application_calendar.calendar_id unless application_calendar.calendar_id.nil?
        conflict_calendar_ids.push(application_calendar.conflict_calendars) unless application_calendar.conflict_calendars.nil?
      end

      if member_application_calendars.count > 0
        application_calendar_id = member_application_calendars[0].calendar_id
        application_access_token = member_application_calendars[0].access_token
        application_refresh_token = member_application_calendars[0].refresh_token
        application_sub = member_application_calendars[0].application_sub
      end

      member_agendas.each do |agenda_app|
        added_calendar_id = agenda_app.calendar_id unless agenda_app.calendar_id.nil?
        conflict_calendar_ids.push(agenda_app.conflict_calendars) unless agenda_app.conflict_calendars.nil?
      end

      if member_agendas.count > 0
        application_calendar_id = member_agendas.first.calendar_id
        application_access_token = member_agendas.first.cronofy_access_token
        application_refresh_token = member_agendas.first.cronofy_refresh_token
        application_sub = member_agendas.first.cronofy_account_id
      end

      @resource.calendar_id = added_calendar_id
      @resource.conflict_calendars = conflict_calendar_ids.count.zero? ? nil : conflict_calendar_ids.join(',')
      @resource.application_calendar_id = application_calendar_id
      @resource.application_access_token = application_access_token
      @resource.application_refresh_token = application_refresh_token
      @resource.application_sub = application_sub
    end

    if @resource.save
      resource_dup.client_id = current_client.id
      resource_dup.save

      Resource.where(id: resource_dup.id).update_all(client_id: nil)
      render json: {result: 'success', message: t('services.resources.updated_success')}, status: 200
    else
      render json: {result: 'error', message: t('services.resources.updated_error') }, status: 422
    end
  end

  def destroy
    resource_id = params[:id]
    resource = Resource.find_by(id: resource_id)
    service = Service.find_by(id: params[:service_id])

    if resource.services.count > 1
      render json: {result: 'error', message: t('services.resources.resource_already_using') } and return
    end

    resource_ids_of_service = service.resources.pluck :id
    if resource_ids_of_service.include?(resource_id.to_i) && resource_ids_of_service.count == 1
      render json: {result: 'error', message: t('services.resources.keep_one_resource') } and return
    end

    resource_dup = Resource.find_by(eid: resource.id)
    resource_dup.destroy if resource_dup
    resource.destroy

    render json: { result: 'success', message: t('services.resources.removed_success') }, status: 200
  end

  def change_enabled
    resource_id = params[:id]
    resource = Resource.find_by(id: resource_id)
    service = Service.find_by(id: params[:service_id])

    active_resource_dependencies = ResourceService.where(service_id: service.id).order(updated_at: :asc)

    Resource.find(active_resource_dependencies[0].resource_id).update_columns(enabled: false)
    Resource.where(eid: active_resource_dependencies[0].resource_id).update_all(enabled: false)

    active_resource_dependencies[0].destroy
    ResourceService.where(service_id: Service.where(eid: service.id).first.id).delete_all

    ResourceService.find_or_create_by({service_id: service.id, resource_id: resource_id})
    ResourceService.find_or_create_by({service_id: Service.where(eid: service.id).first.id, resource_id: Resource.where(eid: resource_id).first.id})
    Resource.where(eid: resource_id).update_all(enabled: true)
    resource.update_columns(enabled: true)

    render json: { result: 'success', message: t('services.resources.changed_enable') }, status: 200
  rescue => e
    puts e
    render json: { result: 'false', message: e.message }, status: 500
  end

  def toggle_enabled
    resource_id = params[:id]
    resource = Resource.find_by(id: resource_id)
    service = Service.find_by(id: params[:service_id])

    resource_dependencies = ResourceService.where(service_id: service.id, resource_id: resource_id)
    if resource_dependencies.size.zero? # it means turn on
      @subscription_plan = current_client.organizations && current_client.organizations.first.chargebee_subscription_plan ? current_client.organizations.first.chargebee_subscription_plan : "free"

      active_resource_dependencies = ResourceService.where(service_id: service.id)

      if @subscription_plan == 'free'
        active_resource_dependencies.each do |dependency|
          Resource.find(dependency.resource_id).update_columns(enabled: false) if ResourceService.where("service_id != ? and resource_id = ?", service.id, dependency.resource_id).count.zero?
          Resource.where(eid: dependency.resource_id).update_all(enabled: false) if ResourceService.where("service_id != ? and resource_id = ?", Service.where(eid: service.id).first.id, Resource.where(eid: dependency.resource_id).first.id).count.zero?
        end

        active_resource_dependencies.delete_all
        ResourceService.where(service_id: Service.where(eid: service.id).first.id).delete_all

        ResourceService.find_or_create_by({service_id: service.id, resource_id: resource_id})
        ResourceService.find_or_create_by({service_id: Service.where(eid: service.id).first.id, resource_id: Resource.where(eid: resource_id).first.id})
        Resource.where(eid: resource_id).update_all(enabled: true)
        resource.update_columns(enabled: true)

        render json: { result: 'success', message: t('services.resources.changed_enable') }, status: 200
      else
        active_resources = []
        existed_full_activated_resources = false
        service.ivr.services.each do |item|
          resource_services = item.resource_services

          unless existed_full_activated_resources
            existed_full_activated_resources = current_client.organizations && current_client.organizations.first.chargebee_seats ? resource_services.count == current_client.organizations.first.chargebee_seats : false
          end

          resource_services.each do |resource_service|
            activated = false

            active_resources.each do |active_resource|
              if active_resource.id == resource_service.resource_id
                activated = true
                break
              end
            end

            active_resources.push(Resource.find(resource_service.resource_id)) if !activated && Resource.find(resource_service.resource_id).client_id
          end
        end

        seatsEnable = current_client.organizations && (current_client.organizations.first.chargebee_subscription_plan == "trial" || (current_client.organizations.first.chargebee_seats ? active_resource_dependencies.count < current_client.organizations.first.chargebee_seats : false))

        if seatsEnable
          existed_activated = false
          if (active_resource_dependencies.count + 1) == current_client.organizations.first.chargebee_seats && existed_full_activated_resources
            active_resources.each do |active_resource|
              puts active_resource.id
              puts resource_id
              if active_resource.id.to_s == resource_id
                existed_activated = true
                break
              end
            end
          else
            existed_activated = true
          end

          if @subscription_plan == 'trial' || existed_activated
            ResourceService.find_or_create_by({service_id: service.id, resource_id: resource_id})
            ResourceService.find_or_create_by({service_id: Service.where(eid: service.id).first.id, resource_id: Resource.where(eid: resource_id).first.id})
            Resource.where(eid: resource_id).update_all(enabled: true)
            resource.update_columns(enabled: true)
          else
            return render json: { result: 'false', message: 'seats' }, status: 200
          end
        else
          return render json: { result: 'false', message: 'seats' }, status: 200
        end
      end
    else # it means turn off
      resource_ids_of_service = service.resources.pluck :id
      if resource_ids_of_service.include?(resource_id.to_i) && resource_ids_of_service.count == 1
        render json: {result: 'error', message: t('services.resources.keep_one_resource') } and return
      end

      resource_dependencies.delete_all
      ResourceService.where({service_id: Service.where(eid: service.id).first.id, resource_id: Resource.where(eid: resource.id).first.id}).delete_all
      resource.update_columns(enabled: false) if ResourceService.where(resource_id: resource_id).count.zero?
      Resource.where(eid: resource.id).update_all(enabled: false) if ResourceService.where(resource_id: Resource.where(eid: resource.id).first.id).count.zero?
    end

    if service.resources.count == 1
      service.update_attributes(resource_distribution: 'one')
    else
      service.update_attributes(resource_distribution: 'invitee') if service.resource_distribution == 'one'
    end

    render json: { result: 'success', message: 'ok' }, status: 200
  end

  def get_availablities
    availabilities = get_schedule_availablities(params[:schedule_id].to_i)
    render json: {availabilities: availabilities[:availabilities], overrides: availabilities[:overrides]}
  end

  def get_calendar_info_of_resource
    resource = Resource.find(params[:resource_id])
    resource_calendar_id = resource.calendar_id
    resource_conflict_calendars = resource.conflict_calendars

    # get agenda for conflict
    resource_conflict_agenda_info = []

    application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id )
    application_calendars.each do |application_calendar|
      resource_conflict_agenda_info.push({
        'name' => application_calendar.name,
        'profile' => application_calendar.name,
        'conflict_calendars' => resource_conflict_calendars.present? && resource_conflict_calendars.split(',').include?(application_calendar.conflict_calendars) ? application_calendar.conflict_calendars : '',
        'provider' => 'application',
        'calendar' => [application_calendar.calendar_name],
        'calendar_id' => [application_calendar.calendar_id]
      })
    end

    current_client.agenda_apps.each do |agenda|
      agenda_info = {'profile' => agenda.cronofy_profile_name, 'provider' => agenda.cronofy_provider_name}
      check_calendar_account = [];
      check_calendar_id = [];
      agenda.all_calendars.each do |calendar|
        if resource_conflict_calendars.present? && resource_conflict_calendars.split(',').include?(calendar[1])
          check_calendar_account.push(calendar[0])
          check_calendar_id.push(calendar[1])
        end
      end
      agenda_info['calendar'] = check_calendar_account
      agenda_info['calendar_id'] = check_calendar_id
      resource_conflict_agenda_info.push(agenda_info)
    end

    # get agenda for "add to calendar"
    resource_agenda_info = nil
    current_client.agenda_apps.each do |agenda|
      agenda.all_calendars.each do |calendar|
        if resource_calendar_id == calendar[1]
          resource_agenda_info = {:profile => agenda.cronofy_profile_name, :calendar => calendar[0], :calendar_id => resource_calendar_id, :calendars => agenda.all_calendars}
          break
        end
      end
    end

    added_application_calendar = application_calendars.count.zero? ? nil : application_calendars[0]

    render json: {is_default: resource.is_default, is_user_account: resource.is_user_account, conflict_calendars: resource_conflict_agenda_info,
                  added_calendars: resource_agenda_info ? resource_agenda_info : added_application_calendar, added_application_calendar: added_application_calendar}
  end

  def get_calendar_info_of_default
    # get agenda for conflict
    conflict_agenda_info = []
    service = Service.find_by(id: params[:current_service_id])
    cur_ivr = Ivr.find(service.ivr_id)
    cur_ivr.client.agenda_apps.where("conflict_calendars IS NOT NULL").each do |agenda|
      agenda_info = {'profile' => agenda.cronofy_profile_name, 'provider' => agenda.cronofy_provider_name}
      check_calendar_account = []
      check_calendar_id = []
      agenda.all_calendars.each do |calendar|
        if agenda.conflict_calendars.split(',').include?(calendar[1])
          check_calendar_account.push(calendar[0])
          check_calendar_id.push(calendar[1])
        end
      end
      agenda_info['calendar'] = check_calendar_account
      agenda_info['calendar_id'] = check_calendar_id
      conflict_agenda_info.push(agenda_info)
    end

    # get agenda for "add to calendar"
    added_calendar_info = nil
    cur_ivr.client.agenda_apps.where("calendar_id IS NOT NULL").each do |agenda|
      agenda.all_calendars.each do |calendar|
        if agenda.calendar_id == calendar[1]
          added_calendar_info = {:profile => agenda.cronofy_profile_name, :calendar => calendar[0], :calendar_id => calendar[1], :calendars => agenda.all_calendars}
          break
        end
      end
    end

    render json: {is_default: true, is_user_account: false, conflict_calendars: conflict_agenda_info, added_calendars: added_calendar_info}
  end


  private

  def resource_params
    params.permit(:resource_name, :resource_ename)
  end

  def set_resource
    @resource = current_client.resources.find_by(id: params[:id])
  end

  def set_first_agenda
    @first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
  end
end
