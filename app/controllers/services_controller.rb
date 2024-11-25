class ServicesController < ApplicationController
  include ApplicationHelper
  before_action :check_ory_session, except: :get_dependencies
  require 'twilio-ruby'

  skip_before_action :verify_authenticity_token
  before_action :set_service, only: %i[update edit_event destroy toggle_enabled toggle_service_options_enabled get_automation automation_enabled]
  before_action :set_subscription_plan, only: %i[index toggle_enabled]
  before_action :set_first_agenda, only: %i[index new_event edit_event create destroy toggle_enabled toggle_service_options_enabled save_agenda_service_resource]
  layout 'layout'

  def index

  end

  def new_event
    ivr = Ivr.find(params[:ivr_id])
    if @first_agenda.is_online_agenda?
      @service = Service.new(agenda_type: @first_agenda)
      exist_services = []
      ivr.services.where(agenda_type: @first_agenda.type, enabled: true).each do |service|
        exist_services.push(service.eid)
      end
      @services = []
      @first_agenda.services.each do |service|
        unless exist_services.include? service['id']
          @services.push({ 'id': service['id'], 'name': service['name']})
        end
      end
    else
      @service = Service.new
      @resources = current_client.resources.where(ivr_id: ivr.id).order(name: :asc)
      @service_customize_availability = BusinessHours::DEFAULT_AVAILABILITY

      @schedule_templates = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc)
      @selected_service_schedule = current_client.schedule_templates.where(is_default: true).first
      @selected_service_schedule_id = @selected_service_schedule.id
    end

    @service.ivr_id = ivr.id
    @all_services = []
    ivr.services.where(agenda_type: @first_agenda.type == 'DummyAgenda' ? 'ClassicAgenda' : @first_agenda.type).each do |service|
      @all_services.push({id: service.eid, name: service.name})
    end
    @questions = []
    @mandatory_question = "first_lastname"
    @reminder_enabled = false
    @followup_enabled = false

    @start_interval = 30
    @start_interval_array = [5, 10, 15, 20, 30, 60]
    @response_format = 'slots'
  end

  def edit_event
    ivr = Ivr.find(@service.ivr_id)
    if @first_agenda.is_online_agenda?
      @resources = ivr.resources.where(ivr_id: ivr.id, agenda_type: @first_agenda.type).order(name: :asc)
    else
      @resources = ivr.client.resources.where(ivr_id: ivr.id).order(is_default: :desc).order(created_at: :asc)
    end

    @all_services = []
    if @first_agenda.type == 'DummyAgenda' || @first_agenda.type == 'ClassicAgenda'
      ivr.services.where(agenda_type: 'ClassicAgenda').each do |service|
        @all_services.push({id: service.eid, name: service.name})
      end
    else
      ivr.services.where(agenda_type: @first_agenda.type).each do |service|
        @all_services.push({id: service.id, name: service.name})
      end
    end

    @schedule_templates = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc)
    @resource_availability = BusinessHours::DEFAULT_AVAILABILITY
    @selected_dependent = @service.resources.pluck :id
    @service.update_attributes(resource_distribution: 'one') if @selected_dependent.size == 1

    @service_customize_availability = @service.availability
    @service_customize_overrides = @service.overrides
    if @service.schedule_template_id.zero?
      # if client user 'customize hours', schedule template is default template.
      @selected_service_schedule = current_client.schedule_templates.where(is_default: true).first
      @selected_availability_type = 'customize'
    else
      # if client user 'default hours', schedule template is selected template.
      @selected_service_schedule = current_client.schedule_templates.find(@service.schedule_template_id)
      @selected_availability_type = 'default'
    end
    @selected_service_schedule_id = @selected_service_schedule.id
    @questions = @service.questions.where("answer_type != 'mandatory'").order(orderno: :asc)
    @mandatory_question = @first_agenda.is_online_agenda? ? 'first_lastname' : @service.questions.where("answer_type = 'mandatory'").first.text

    @reminder = ivr.reminder.where(service_id: @service.id).first
    @reminder_enabled = @first_agenda.is_online_agenda? ? false : @reminder.enabled
    followup_node = ivr.find_node('hangup_caller_sms')
    @followup_enabled = followup_node ? followup_node.enabled : false

    @start_interval_array = [5, 10, 15, 20, 30, 60]
    @start_interval = @service.start_interval
    @response_format = @service.response_format

    response_format = get_response_format_example(@service.duration, @service.start_interval, @service.buffer)
    @response_format_slot_example = response_format[:slot_example]
    @response_format_overlapping_example = response_format[:overlapping_example]

    @present_order = ivr.preference['widget_dropdown_default_resource'] || 'serviceFirst'

    @services = []
    @services.push({ 'id': @service.eid, 'name': @service.name, 'ename': @service.ename})

    @calendar_enabled_members = []
    invitations = Invitation.where("organization_id = ? AND status LIKE ? AND enable_calendar = ?", session[:current_organization].id, "accept" + "%", true)
    invitations.each do |invitation|
      client = Client.find_by_email(invitation.to_email)
      application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: client.id )
      @calendar_enabled_members.push({ id: client.id, name: client.full_name, calendars: client.agenda_apps.count > 0 || application_calendars.count > 0 ? true : false })
    end
  rescue => e
    puts e
  end

  def create
    ivr = Ivr.find(params[:cur_ivr])
    service = Service.new(service_params.merge({client: current_client, ivr: ivr}))
    service.ename = params[:service][:ename]
    service.name = params[:service][:name].blank? ? params[:service][:ename] : params[:service][:name]
    service.preference[:ai_phone_assistant_enabled] = false
    service.preference[:phone_assistant_enabled] = true
    default_schedule = current_client.schedule_templates.where(is_default: true).first
    service.schedule_template_id = default_schedule.id
    service.availability = default_schedule.availability.availabilities.to_json
    service.overrides = default_schedule.availability.overrides
    respond_to do |format|
      if service.save
        # default question for mandatory field (fullname, first and last name)
        question = service.questions.new(text: 'first_lastname', answer_type: 'mandatory', enabled: true)
        question.save

        # default reminder
        email_invitee_subject = t('mails.reminder_email_invitee.subject')
        email_invitee_body = t('mails.reminder_email_invitee.body')
        sms_invitee_body = t('mails.reminder_sms_invitee.body')
        Reminder.create(advance_time_offset: 10, advance_time_duration: '-', time: '', sms: true, email: false, email_subject: email_invitee_subject, text: email_invitee_body, email_subject_host: email_invitee_subject, text_host: email_invitee_body,
                        sms_text: sms_invitee_body, client_id: current_client.id, ivr_id: ivr.id, service_id: service.id, enabled: true)

        # service duplication
        service_dup = Service.new(service_params.merge({ client: current_client, ivr: ivr }))
        service_dup.name = service.name
        service_dup.ename = service.ename
        service_dup.agenda_type = "ClassicAgenda"
        service_dup.eid = service.id
        service_dup.order_id = service.order_id + 1
        service_dup.preference[:ai_phone_assistant_enabled] = false
        service_dup.schedule_template_id = default_schedule.id
        service_dup.availability = default_schedule.availability.availabilities.to_json
        service_dup.overrides = default_schedule.availability.overrides
        service_dup.save
        Service.where(id: service_dup.id).update_all(client_id: nil)

        default_resource = ivr.resources.where(is_default: true).first
        if default_resource
          ResourceService.find_or_create_by({service_id: service.id, resource_id: default_resource.id})
          if Resource.where(eid: default_resource.id).count.zero?
            resource_dup = Resource.new(ivr_id: ivr.id, client_id: current_client.id, enabled: true, is_default: false, name: default_resource.name, ename: default_resource.ename, eid: default_resource.id)
            resource_dup.save
            Resource.where(id: resource_dup.id).update_all(client_id: nil, agenda_type: "ClassicAgenda")
          end
          ResourceService.find_or_create_by({service_id: Service.where(eid: service.id).first.id, resource_id: Resource.where(eid: default_resource.id).first.id})
          Resource.where(eid: default_resource.id).update_all(enabled: true)
        end

        format.html { redirect_to services_services_path() }
      else
        format.html { render :new_event }
      end
    end
  end

  def update
    @service.ename = params[:service][:ename]
    @service.name = params[:service][:name].blank? ? params[:service][:ename] : params[:service][:name]
    @service.duration = params[:service][:duration] if params[:service][:duration]
    @service.buffer = params[:service][:buffer] if params[:service][:buffer]
    @service.buffer_before = params[:service][:buffer_before] if params[:service][:buffer_before]
    @service.buffer_after = params[:service][:buffer_after] if params[:service][:buffer_after]
    @service.response_format = params[:response_format_type] if params[:response_format_type]
    @service.start_interval = params[:start_interval] if params[:start_interval]
    @service.resource_distribution = params[:resource_distribution] if params[:resource_distribution]

    service_dup = Service.where(eid: @service.id, agenda_type: 'ClassicAgenda').first
    if service_dup
      service_dup.name = @service.name
      service_dup.ename = @service.ename
      service_dup.duration = params[:service][:duration] if params[:service][:duration]
      service_dup.buffer = params[:service][:buffer] if params[:service][:buffer]
      service_dup.buffer_before = params[:service][:buffer_before] if params[:service][:buffer_before]
      service_dup.buffer_after = params[:service][:buffer_after] if params[:service][:buffer_after]
      service_dup.response_format = params[:response_format_type] if params[:response_format_type]
      service_dup.start_interval = params[:start_interval] if params[:start_interval]
      service_dup.resource_distribution = params[:resource_distribution] if params[:resource_distribution]
    end

    service_availability_type = params[:service_availability_category] if params[:service_availability_category]
    if service_availability_type == 'default'
      @service.use_default_availability = true
      service_schedule_template = current_client.schedule_templates.find(params[:service_schedule_templates])
      @service.schedule_template_id = service_schedule_template.id
      @service.availability = service_schedule_template.availability.availabilities.to_json
      @service.overrides = service_schedule_template.availability.overrides.nil? || service_schedule_template.availability.overrides.empty? ? nil : service_schedule_template.availability.overrides

      if service_dup
        service_dup.use_default_availability = @service.use_default_availability
        service_dup.schedule_template_id = @service.schedule_template_id
        service_dup.availability = service_schedule_template.availability.availabilities.to_json
        service_dup.overrides = service_schedule_template.availability.overrides.nil? || service_schedule_template.availability.overrides.empty? ? nil : service_schedule_template.availability.overrides
      end
    end

    if service_availability_type == 'customize'
      @service.use_default_availability = false
      @service.schedule_template_id = 0
      service_avaialbility_hours = availabilities_hours(params[:service_hours])
      service_override_hours = override_hours(params[:service_hours_override_hours])
      @service.availability = service_avaialbility_hours.to_json
      @service.overrides = service_override_hours.empty? ? nil : service_override_hours

      if service_dup
        service_dup.use_default_availability = @service.use_default_availability
        service_dup.schedule_template_id = @service.schedule_template_id
        service_dup.availability = service_avaialbility_hours.to_json
        service_dup.overrides = service_override_hours.empty? ? nil : service_override_hours
      end
    end

    respond_to do |format|
      # format.html { redirect_to services_path }
      if @service.save
        service_dup.client_id = current_client.id
        service_dup.save

        Service.where(id: service_dup.id).update_all(client_id: nil)
        format.html { redirect_to services_path }
      else
        format.html { render :edit }
      end
    end
  end

  def destroy
    if @first_agenda.is_online_agenda?
      active_services = Ivr.find(params[:ivr_id]).services.active.where('id != ? AND client_id IS NOT NULL AND agenda_type = ?', @service.id, @first_agenda.type).order(name: :asc)
    else
      active_services = Ivr.find(params[:ivr_id]).services.active.where('id != ? AND client_id IS NOT NULL AND agenda_type IS NULL', @service.id).order(name: :asc)
    end

    if active_services.count.zero?
      render json: {result: 'error', message: t('services.keep_one_service') } and return
    end

    service_dup = Service.where(:eid => @service.id).first
    service_dup.destroy if service_dup
    @service.destroy

    render json: { result: 'success', message: 'ok' }, status: 200
  end

  # get availabilits of schdule
  def get_availablities
    availabilities = get_schedule_availablities(params[:schedule_id].to_i)
    render json: {availabilities: availabilities[:availabilities], overrides: availabilities[:overrides]}
  end

  def save_as_schedule
    schedule_name = params[:schedule_name]
    availability_hours = get_available_hours(params[:working_hours])
    override_hours = get_available_hours(params[:override_hours])

    new_schedule = current_client.schedule_templates.new(template_name: schedule_name, is_default: false)
    new_schedule.save
    if new_schedule.save
      new_availability = Availability.new(schedule_template_id: new_schedule.id, availabilities: availability_hours, overrides: override_hours)
      if new_availability.save
        render json: {result: 'success', new_schedule_id: new_schedule.id, message: t('availabilities.save_success') } and return
      else
        render json: {result: 'error', message: new_availability.errors.full_messages } and return
      end
    else
      render json: {result: 'error', message: new_schedule.errors.full_messages } and return
    end
  end

  def save_automation
    service = Service.find_by(id: params[:current_service_id])
    automation_type = params[:automation_type]
    save_email_invitee_result = true
    save_email_host_result = true
    save_sms_invitee_result = true
    save_sms_host_result = true

    email_invitee_automation_type = automation_type + "_email_invitee"
    email_host_automation_type = automation_type + "_email_host"
    email_invitee_subject = params[:email_invitee_subject]
    email_invitee_body = params[:email_invitee_body]
    email_host_subject = params[:email_host_subject]
    email_host_body = params[:email_host_body]

    sms_invitee_automation_type = automation_type + "_sms_invitee"
    sms_invitee_body = params[:sms_invitee_body]

    sms_host_automation_type = automation_type + "_sms_host"
    sms_host_body = params[:sms_host_body]

    email_host_switch = params[:email_host_switch_value] == "true" ? true : false
    sms_invitee_switch = params[:sms_invitee_switch_value] == "true" ? true : false
    sms_host_switch = params[:sms_host_switch_value] == "true" ? true : false
    invitee_include_cancel_link = params[:invitee_include_cancel_link_value] == "true" ? true : false
    host_include_cancel_link = params[:host_include_cancel_link_value] == "true" ? true : false

    if automation_type == 'confirmation' || automation_type == 'cancellation' || automation_type == 'rescheduling'
      # Save Email Host Information
      email_host_automation = service.service_notifications.where(automation_type: email_host_automation_type)
      if email_host_automation.count.zero?
        new_service_notification = service.service_notifications.new(client_id: service.client_id, service_id: service.id, automation_type: email_host_automation_type, subject: email_host_subject, text: email_host_body, use_email_host: email_host_switch)
        save_email_host_result = new_service_notification.save
      else
        save_email_host_result = email_host_automation.update_all(subject: email_host_subject, text: email_host_body, use_email_host: email_host_switch)
      end

      # Save Email Invitee  Information
      email_invitee_automation = service.service_notifications.where(automation_type: email_invitee_automation_type)
      if email_invitee_automation.count.zero?
        new_service_notification = service.service_notifications.new(client_id: service.client_id, service_id: service.id, is_include_cancel_link: invitee_include_cancel_link,
                                                                            automation_type: email_invitee_automation_type, subject: email_invitee_subject, text: email_invitee_body)
        save_email_invitee_result = new_service_notification.save
      else
        save_email_invitee_result = email_invitee_automation.update_all(subject: email_invitee_subject, text: email_invitee_body, is_include_cancel_link: invitee_include_cancel_link)
      end

      # Save SMS Invitee Information
      sms_invitee_automation = service.service_notifications.where(automation_type: sms_invitee_automation_type)
      if sms_invitee_automation.count.zero?
        new_service_notification = service.service_notifications.new(client_id: service.client_id, service_id: service.id, use_sms_invitee: sms_invitee_switch,
                                                                            automation_type: sms_invitee_automation_type, text: sms_invitee_body)
        save_sms_invitee_result = new_service_notification.save
      else
        save_sms_invitee_result = sms_invitee_automation.update_all(text: sms_invitee_body, use_sms_invitee: sms_invitee_switch)
      end

      # Save SMS Host Information
      sms_host_automation = service.service_notifications.where(automation_type: sms_host_automation_type)
      if sms_host_automation.count.zero?
        new_service_notification = service.service_notifications.new(client_id: service.client_id, service_id: service.id, use_sms_host: sms_host_switch,
                                                                            automation_type: sms_host_automation_type, text: sms_host_body)
        save_sms_host_result = new_service_notification.save
      else
        save_sms_host_result = sms_host_automation.update_all(text: sms_host_body, use_sms_host: sms_host_switch)
      end
    end

    if automation_type == 'confirmation' || automation_type == 'rescheduling'
      node = service.ivr.find_node("appointment_success_client_sms")
      node.text = sms_host_body.gsub(/<[^>]*>/,'')
      node.enabled = sms_host_switch
      node.save

      node = service.ivr.find_node("appointment_success_caller_sms")
      node.text = sms_invitee_body.gsub(/<[^>]*>/,'')
      node.enabled = sms_invitee_switch
      node.save
    end

    if automation_type == 'cancellation'
      node = service.ivr.find_node("appointment_cancel_caller_sms")
      node.text = sms_invitee_body.gsub(/<[^>]*>/,'')
      node.enabled = sms_invitee_switch
      node.save
    end

    if automation_type == 'reminder'
      ivr = Ivr.find(service.ivr_id)
      reminder = ivr.reminder.where(service_id: service.id)
      is_include_agenda = params[:is_include_agenda_value] == "true" ? true : false

      trigger_type = params[:trigger_type_value]
      if trigger_type == 'trigger_event_specific_time'
        time_offset = params[:trigger_specific_offset_value]
        advance_time_duration = params[:trigger_specific_duration_value]
        time_value = params[:trigger_specific_time_value]
        time_duration = ''
      end
      if trigger_type == 'trigger_event_before_start'
        time_offset = params[:trigger_time_value]
        advance_time_duration = '-'
        time_value = ''
        time_duration = params[:trigger_duration_value]
        time_offset = time_offset.to_i * 60 if time_duration == 'hours'
        time_offset = time_offset.to_i * 60 * 24 if time_duration == 'days'
      end

      unless reminder.count.zero?
        reminder.first.update(advance_time_offset: time_offset, advance_time_duration: advance_time_duration, time: time_value, sms: sms_invitee_switch,
                              email: email_host_switch, text: email_invitee_body, sms_text: sms_invitee_body, email_subject: email_invitee_subject, text_host: email_host_body, email_subject_host: email_host_subject,
                              is_include_cancel_link: invitee_include_cancel_link, is_include_agenda: is_include_agenda, time_duration: time_duration)
      else
        Reminder.create(advance_time_offset: time_offset, advance_time_duration: advance_time_duration, time: time_value, sms: sms_invitee_switch,
                        email: email_host_switch, text: email_invitee_body, sms_text: sms_invitee_body, email_subject: email_invitee_subject, email_subject_host: email_host_subject, text_host: email_host_body, client_id: ivr.client.id,
                        ivr_id: ivr.id, service_id: service.id, is_include_cancel_link: invitee_include_cancel_link, is_include_agenda: is_include_agenda, time_duration: time_duration)
      end
    end

    if automation_type == 'followup'
      ivr = Ivr.find(service.ivr_id)
      followup_node = ivr.find_node('hangup_caller_sms')
      if followup_node
        followup_node.update(text: sms_invitee_body, enabled: sms_invitee_switch)
      end
    end

    ivr = Ivr.find(service.ivr_id)
    reminder = ivr.reminder.find_by(service_id: service.id)

    render json: {result: 'success', message: t('common.save_success'), reminder: reminder } if save_email_invitee_result && save_email_host_result && save_sms_invitee_result && save_sms_host_result
    render json: {result: 'error', message: t('common.save_failure') } unless save_email_invitee_result || save_email_host_result || save_sms_invitee_result || save_sms_host_result
  end

  def get_automation
    is_include_agenda = false
    automation_type = params[:automation_type]
    ivr = Ivr.find(@service.ivr_id)

    if automation_type == 'confirmation' || automation_type == 'cancellation' || automation_type == 'rescheduling'
      email_invitee = @service.service_notifications.where(automation_type: "#{automation_type}_email_invitee")
      if email_invitee.count.zero?
        email_invitee_subject = t("mails.#{automation_type}_email_invitee.subject").html_safe
        email_invitee_body = t("mails.#{automation_type}_email_invitee.body").html_safe
        invitee_include_cancel_link = true
      else
        email_invitee_subject = email_invitee.first.subject
        email_invitee_body = email_invitee.first.text
        invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
      end

      email_host = @service.service_notifications.where(automation_type: "#{automation_type}_email_host")
      if email_host.count.zero?
        email_host_subject = t("mails.#{automation_type}_email_host.subject").html_safe
        email_host_body = t("mails.#{automation_type}_email_host.body").html_safe
        host_include_cancel_link = false
        email_host_switch_value = false
      else
        email_host_subject = email_host.first.subject
        email_host_body = email_host.first.text
        host_include_cancel_link = email_host.first.is_include_cancel_link
        email_host_switch_value = email_host.first.use_email_host
      end

      sms_invitee = @service.service_notifications.where(automation_type: "#{automation_type}_sms_invitee")
      if sms_invitee.count.zero?
        sms_invitee_body = t("mails.#{automation_type}_sms_invitee.body").html_safe
        sms_invitee_switch_value = false
      else
        sms_invitee_body = sms_invitee.first.text
        sms_invitee_switch_value = sms_invitee.first.use_sms_invitee
      end

      sms_host = @service.service_notifications.where(automation_type: "#{automation_type}_sms_host")
      if sms_host.count.zero?
        sms_host_body = t("mails.#{automation_type}_sms_host.body").html_safe
        sms_host_switch_value = false
      else
        sms_host_body = sms_host.first.text
        sms_host_switch_value = sms_host.first.use_sms_host
      end
    end

    if automation_type == 'confirmation' || automation_type == 'rescheduling'
      node = @service.ivr.find_node("appointment_success_client_sms")
      sms_host_body = node.text
      sms_host_switch_value = node.enabled

      node = @service.ivr.find_node("appointment_success_caller_sms")
      sms_invitee_body = node.text
      sms_invitee_switch_value = node.enabled
    end

    if automation_type == 'cancellation'
      node = @service.ivr.find_node("appointment_cancel_caller_sms")
      sms_invitee_body = node.text
      sms_invitee_switch_value = node.enabled

      sms_host_body = node.text
      sms_host_switch_value = node.enabled
    end

    if automation_type == 'reminder'
      reminder = ivr.reminder.where(service_id: @service.id)
      unless reminder.count.zero?
        email_invitee_subject = reminder.first.email_subject
        email_invitee_body = reminder.first.text
        email_host_subject = reminder.first.email_subject_host
        email_host_body = reminder.first.text_host
        sms_invitee_body = reminder.first.sms_text
        sms_invitee_switch_value = reminder.first.sms
        invitee_include_cancel_link = reminder.first.is_include_cancel_link
        is_include_agenda = reminder.first.is_include_agenda
        email_host_switch_value = reminder.first.email
      else
        email_invitee_subject = t('mails.reminder_email_invitee.subject')
        email_invitee_body = t('mails.reminder_email_invitee.body')
        email_host_subject = t('mails.reminder_email_invitee.subject')
        email_host_body = t('mails.reminder_email_invitee.body')
        sms_invitee_body = t('mails.reminder_sms_invitee.body')
        sms_invitee_switch_value = true
        invitee_include_cancel_link = false
        is_include_agenda = true
        email_host_switch_value = false
      end
      host_include_cancel_link = false
      sms_host_switch_value = false
    end

    if automation_type == 'followup'
      email_invitee_subject = ''
      email_invitee_body = ''
      email_host_subject = ''
      email_host_body = ''
      followup_node = ivr.find_node('hangup_caller_sms')
      sms_invitee_body = followup_node&.text
      sms_invitee_switch_value = followup_node&.enabled
      sms_host_switch_value = false
      invitee_include_cancel_link = false
      host_include_cancel_link = false
    end

    invitee_include_cancel_link = false if invitee_include_cancel_link.nil?
    host_include_cancel_link = false if host_include_cancel_link.nil?

    render json: { email_invitee_subject: email_invitee_subject, email_invitee_body: email_invitee_body, sms_invitee_switch_value: sms_invitee_switch_value, sms_host_switch_value: sms_host_switch_value,
                   email_host_subject: email_host_subject, email_host_body: email_host_body, sms_invitee_body: sms_invitee_body, sms_host_body: sms_host_body,
                   invitee_include_cancel_link: invitee_include_cancel_link, host_include_cancel_link: host_include_cancel_link, is_include_agenda: is_include_agenda, email_host_switch_value: email_host_switch_value }
  end

  def automation_enabled
    automation_type = params[:automation_type]
    automation_enabled = params[:enabled]

    if automation_type == 'reminder'
      ivr = Ivr.find(@service.ivr_id)
      reminder = ivr.reminder.where(service_id: @service.id)
      unless reminder.count.zero?
        reminder.first.update(enabled: automation_enabled)
      else
        email_invitee_subject = t('mails.reminder_email_invitee.subject')
        email_invitee_body = t('mails.reminder_email_invitee.body')
        sms_invitee_body = t('mails.reminder_sms_invitee.body')
        Reminder.create(advance_time_offset: 10, advance_time_duration: '-', time: '', sms: false, email: false, email_subject: email_invitee_subject, text: email_invitee_body, email_subject_host: email_invitee_subject, text_host: email_invitee_body,
                        sms_text: sms_invitee_body, client_id: ivr.client.id, ivr_id: ivr.id, service_id: @service.id, enabled: automation_enabled)
      end
    end

    if automation_type == 'followup'
      ivr = Ivr.find(@service.ivr_id)
      followup_node = ivr.find_node('hangup_caller_sms')
      followup_node.update(enabled: automation_enabled) if followup_node
    end

    render json: {result: 'success', message: t('common.save_success') }
  end

  def save_question
    service_id = params[:service_id]
    Question.where(answer_type: 'mandatory', service_id: service_id).first.update_columns(text: params[:mandatory_question])
    new_question_ids = []
    questions_data = JSON.parse(params[:question_data])
    questions_data.each do |question_data|
      question_id = question_data['id'].to_i
      question = question_id.zero? ? Question.new : Question.find(question_id)
      question.text = question_data['text']
      question.answer_type = question_data['answer_type']
      question.enabled = question_data['enabled']
      question.mandatory = question_data['required']
      question.orderno = question_data['orderno']
      question.service_id = service_id
      question.save!

      new_question_ids.push(question.id)
      question.question_options.delete_all unless question_id.zero?
      question_data['options'].each do |option|
        QuestionOption.create(text: option['text'], orderno: option['orderno'], question_id: question.id)
      end
    end

    delete_question_ids = params[:delete_question_ids]
    delete_question_ids&.each do |question_id|
      Question.find(question_id.to_i).destroy unless question_id.to_i.zero?
    end

    render json: {result: 'success', message: t('common.save_success'), question_ids: new_question_ids}
  end

  def get_resources_of_selected_service
    service_eid = params[:service_id]
    ivr = Ivr.find(params[:cur_ivr])
    services = ivr.services.where(eid: service_eid)
    if services.count.zero?
      render json: { result: 'failure', resources: nil}
    else
      service = services.first
      render json: { result: 'success', resources: service.resources}
    end
  end

  def get_dependencies
    result = {}
    if params[:type] == "Resource"
      object = Resource.find params["id"] rescue Resource.new
      result[:data] = current_client.services.map {|s| {'id' => s.id, 'name' => s.name, 'ename' => s.ename}} if current_client
      result[:selected_data] = object.services.pluck :id
      result[:dependent_services] = object.services.pluck(:id, :name, :ename)
    else
      object = Service.find params["id"] rescue Service.new
      result[:data] = current_client.resources.map {|s| {'id' => s.id, 'name' => s.name, 'ename' => s.ename}} if current_client
      result[:selected_data] = object.resources.pluck :id
      result[:dependent_resources] = object.resources.pluck(:id, :name, :ename)
      result[:duration] = object.duration
      result[:buffer_before] = object.buffer_before
      result[:buffer_after] = object.buffer_after
      result[:buffer] = object.buffer
    end
    render json: result
  end

  # for mobminder & timify
  def save_agenda_service_resource
    ivr = Ivr.find(params[:cur_ivr])
    service_eid = params[:service_eid]
    service_name = params[:service_name].present? ? params[:service_name] : params[:service_ename]
    selected_services = ivr.services.where(eid: service_eid, agenda_type: @first_agenda.type)
    if selected_services.count.zero?
      selected_service = Service.new(ivr_id: ivr.id, eid: service_eid, name: service_name, ename: params[:service_ename], client_id: current_client.id,
                                agenda_type: @first_agenda.type, duration: 30, enabled: true,
                                preference: {"pre_confirmation"=>"false", "enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"true", "sms_enabled"=>"true", "ai_phone_assistant_enabled"=>"false"})
      selected_service.save
    else
      selected_service = selected_services.first
      selected_service.update_attributes(enabled: true, name: service_name)
    end

    resource_ids = []
    resource_eids = params[:resource_eid].split(',')
    resource_enames = params[:resource_ename].split(',')
    resource_names = params[:resource_name].split(',')
    resource_names.each_with_index do |resource_name, index|
      selected_resources = Resource.where(ivr_id: ivr.id, agenda_type: @first_agenda.type, eid: resource_eids[index])
      if selected_resources.count.zero?
        selected_resource = Resource.new(ivr_id: ivr.id, eid: resource_eids[index], name: resource_name, ename: resource_enames[index], client_id: current_client.id,
                                    agenda_type: @first_agenda.type, enabled: true)
        selected_resource.save
        resource_ids.push(selected_resource.id)
      else
        selected_resource = selected_resources.first
        selected_resource.update_attributes(name: resource_enames[index], name: resource_name)
        resource_ids.push(selected_resources.first.id)
      end
    end
    selected_service.resource_ids = resource_ids
  end

  # turn on/off of service
  def toggle_enabled
    if @first_agenda.is_online_agenda?
      active_services = Ivr.find(params[:ivr_id]).client.services.active.where(ivr_id: params[:ivr_id], agenda_type: @first_agenda.type).order(id: :asc)
    else
      active_services = Ivr.find(params[:ivr_id]).client.services.active.where(ivr_id: params[:ivr_id], agenda_type: nil).order(id: :asc)
    end

    # clicked 'turn off' and activated services count is 1
    render json: {result: 'error', message: t('services.keep_one_service') } and return if active_services.count == 1 && @service.enabled

    if @subscription_plan == 'free' && ! @service.enabled
      # if user is on free plan and clicked 'turn on', disable current activated service
      first_active_service = active_services.first
      if first_active_service
        first_active_service.enabled = false
        first_active_service.preference["widget_enabled"] = false
        first_active_service.preference["phone_assistant_enabled"] = false
        first_active_service.preference["chat_enabled"] = false
        first_active_service.preference["sms_enabled"] = false
        first_active_service.preference["ai_phone_assistant_enabled"] = false
        first_active_service.save
        Service.where(eid: first_active_service.id).update_all(enabled: false)
      end

      message = "You are on free plan and you can only have ONE service enabled. So selected service will be enable and others will be disable."
    else
      message = "ok"
    end

    if @subscription_plan != 'free' && @service.enabled
      # if user is on paid plan and clicked 'turn off' the service that "Phone" toggle is ON, turn on the "Phone" toggle of first enabled service.
      phone_booking_enabled_services = active_services.where("preference->>'phone_assistant_enabled' = ?", "true")
      if phone_booking_enabled_services.count == 1 && phone_booking_enabled_services.first.id == @service.id
        @service.preference["phone_assistant_enabled"] = false

        first_active_service = active_services.where.not(id: @service.id).first
        first_active_service.preference["phone_assistant_enabled"] = true
        first_active_service.preference["ai_phone_assistant_enabled"] = false
        first_active_service.save
      end
    end

    @service.preference["phone_assistant_enabled"] = true unless @service.enabled # if enable the service, phone booking is true
    # enable selected service
    @service.enabled = !@service.enabled
    @service.preference["widget_enabled"] = @service.enabled

    if @service.save
      Service.where(eid: @service.id).update_all(enabled: @service.enabled) unless @service.preference["phone_assistant_enabled"] == "false"
      render json: { result: 'success', message: message }, status: 200
    else
      render json: { result: 'error', message: @service.errors.full_messages }, status: 422
    end
  end

  def get_phone_countries
    countries = []
    phone_number_countries = twilioclient.available_phone_numbers.list()
    phone_number_countries.each do |record|
      countries.push({id: record.country_code, text: record.country})
    end
    render json: { result: 'success', countries: countries }, status: 200
  rescue => e
    render json: { result: 'error', message: e.message }, status: 200
  end

  def number_list
    country_code = params[:country_code]
    pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))
    phone_data = pricing_details.symbolize_keys[:phone_number]

    default_phone_margin = fetch_phone_margin(phone_data)
    user_phone_margin = nil
    if phone_data.include? country_code
      user_phone_margin = fetch_phone_margin(phone_data[country_code])
    end
    phone_local_margin = user_phone_margin.nil? || user_phone_margin[:local].nil? ? default_phone_margin[:local] : user_phone_margin[:local]
    phone_mobile_margin = user_phone_margin.nil? || user_phone_margin[:mobile].nil? ? default_phone_margin[:mobile] : user_phone_margin[:mobile]
    phone_national_margin = user_phone_margin.nil? || user_phone_margin[:national].nil? ? default_phone_margin[:national] : user_phone_margin[:national]

    phone_local_margin = fetch_margin_val(phone_local_margin.to_i)
    phone_mobile_margin = fetch_margin_val(phone_mobile_margin.to_i)
    phone_national_margin = fetch_margin_val(phone_national_margin.to_i)

    local_base_price = 0
    mobile_base_price = 0
    national_base_price = 0
    phone_prices = twilioclient.pricing.v1.phone_numbers.countries(country_code).fetch
    (phone_prices&.phone_number_prices || []).each do |data|
      local_base_price = data['base_price'].to_f if data['number_type'] == 'local'
      mobile_base_price = data['base_price'].to_f if data['number_type'] == 'mobile'
      national_base_price = data['base_price'].to_f if data['number_type'] == 'toll free'
    end
    local_price = (local_base_price * phone_local_margin).round(2)
    mobile_price = (mobile_base_price * phone_mobile_margin).round(2)
    national_price = (national_base_price * phone_national_margin).round(2)

    numbers = []
    filter = {}
    filter.merge!(sms_enabled: true) if params[:sms] == "true"
    filter.merge!(voice_enabled: true) if params[:voice] == "true"
    country_label = params[:country_label]

    if params[:local] == "true"
      begin
        local = twilioclient.available_phone_numbers(country_code).local.list(filter)
        local.each do |record|
          numbers.push({
                         phone_number: record.phone_number,
                         capabilities: record.capabilities,
                         address_requirements: record.address_requirements,
                         type: "local",
                         country_code: country_code,
                         country_label: country_label,
                         phone_price: local_price
                       })
        end
      rescue => e
        puts e
      end
    end

    if params[:mobile] == "true"
      begin
        mobile = twilioclient.available_phone_numbers(country_code).mobile.list(filter)
        mobile.each do |record|
          numbers.push({
                         phone_number: record.phone_number,
                         capabilities: record.capabilities,
                         address_requirements: record.address_requirements,
                         type: "mobile",
                         country_code: country_code,
                         country_label: country_label,
                         phone_price: mobile_price
                       })
        end
      rescue => e
        puts e
      end
    end

    if params[:toll_free] == "true"
      begin
        toll_free = twilioclient.available_phone_numbers(country_code).toll_free.list(filter)
        toll_free.each do |record|
          numbers.push({
                         phone_number: record.phone_number,
                         capabilities: record.capabilities,
                         address_requirements: record.address_requirements,
                         type: "toll_free",
                         country_code: country_code,
                         country_label: country_label,
                         phone_price: national_price
                       })
        end
      rescue => e
        puts e
      end
    end

    return render json: { success: true, numbers: numbers }, status: 200
  rescue => e
    puts e
    return render json: { success: false, message: e.message }, status: 500
  end

  # turn on/off service options(web booking, phone booking, etc...)
  def toggle_service_options_enabled
    option = params[:option]
    option_value = !@service.preference[option]
    option_value = params[:value] unless params[:value].blank?
    option_value = false if option_value == "false"
    @service.preference[option] = option_value

    ivr = Ivr.find(@service.ivr_id)
    if option_value == "false" || option_value == false
      # if services that phone booking toggle is on is only 1, can not turn off the phone toggle.
      if @first_agenda.is_online_agenda?
        active_services = ivr.client.services.active.where(ivr_id: ivr.id, agenda_type: @first_agenda.type)
      else
        active_services = ivr.client.services.active.where(ivr_id: ivr.id, agenda_type: nil)
      end

      phone_booking_enabled_services = active_services.where("preference->>'phone_assistant_enabled' = ?", "true")
      render json: {result: 'warning', message: t('services.keep_one_phone_service') } and return if phone_booking_enabled_services.count == 1
    end

    if @service.save
      if option == "phone_assistant_enabled" && option_value == true
        objects = Service.where(:eid => @service.id)
        objects.each do |object|
          result = Service.where(id: object.id).update_all(enabled: true, client_id: nil)
          if result
            object.resources.update_all(enabled: true)
            # ResourceService.where(:service_id => object.id).delete_all()
            @service.resources.each do |resource|
              ResourceService.find_or_create_by(service_id: object.id, resource_id: Resource.where(eid: resource.id).first.id)
            end
          end
        end
      end

      if option == "phone_assistant_enabled" && option_value == false
        objects = Service.where(:eid => @service.id)
        objects.each do |object|
          result = Service.where(id: object.id).update_all(enabled: false)
          if result
            object.resources.update_all(enabled: false)
            ResourceService.where(:service_id => object.id).delete_all()
          end
        end
      end

      render json: { result: 'success', message: "#{t(params[:option])} #{ @service.preference[params[:option]] ? t('services.true') : t('services.false')}" }, status: :ok
    else
      render json: { result: 'error', message: @service.errors.full_messages }, status: :ok
    end
  rescue Exception => e
    puts e.message
  end

  def get_slot_example
    response_format = get_response_format_example(params[:duration].to_i, params[:start_interval].to_i, params[:extra_time].to_i)
    render json: { slot_example: response_format[:slot_example], overlapping_example: response_format[:overlapping_example] }
  end

  def order_number
    ivr = Ivr.find_by_id(params[:ivr_id])
    AdminMailer.new_number_request_to_admin(ivr, params).deliver_now
    AdminMailer.new_number_request_to_client(ivr).deliver_now
    render json: {result: 'success', message: t('services.new_number_requested')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end

  def buy_no_address_number
    phone_number = params[:phone_number]
    phone_number = "+15005550006" unless ENV['APP_ENV'] == 'prod'

    filter = { phone_number: phone_number, status_callback: "#{ENV['DOMAIN']}/status_callback" }
    filter.merge!(voice_url: 'https://app.voxiplan.com/run') if params[:voice] == "true"
    # filter.merge!(sms_url: 'https://app.voxiplan.com/sms') if params[:sms] == "true"

    incoming_phone_number = ENV['APP_ENV'] == 'prod' ? twilioclient.incoming_phone_numbers.create(filter) : dev_twilioclient.incoming_phone_numbers.create(filter)

    phone_price = params[:phone_price]
    Identifier.create(identifier: phone_number, ivr_id: params[:ivr_id], phone_type: params[:phone_type], phone_price: phone_price)
    PhoneNumber.create(number: phone_number, friendly_name: incoming_phone_number.friendly_name, sms: params[:sms] == "true", voice: params[:voice] == "true", client_id: current_client.id, phone_type: params[:phone_type].capitalize())

    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    result = ChargeBee::Subscription.update_for_items(current_client.organizations.first.chargebee_subscription_id,{
                              :invoice_immediately => false,
                              :subscription_items => [{
                                :item_price_id => ENV["PHONE_NUMBER_#{current_client.currency_code}_ID"],
                                :quantity => 1,
                                :unit_price => phone_price.to_f.round()
                              }]
    })
    puts result

    return render json: { result: 'success', message: t('services.bought_number') + phone_number }, status: 200
  rescue => e
    puts e
    return render json: { result: 'error', message: e.message }, status: 500
  end

  def set_phone_type_of_ivr
    ivr = Ivr.find(params[:ivr_id])

    phone_type = params[:phone_type]
    voice = TelephonyEngine.voices.find{|v| v[:voice] == ivr.voice}
    message = TelephonyEngine.voices.find{|v| v[:voice] == ivr.message}

    ivr.preference['only_ai'] = phone_type == 'ai' ? true : false
    ivr.preference['play_enabled'] = phone_type != 'ai' && voice && voice[:tts] == 'google' || phone_type == 'ai' && message && message[:tts] == 'google'
    ivr.save
    render json: {result: 'success', message: t('common.save_success')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end

  def set_read_tutorial
    current_client.update_column(:read_tutorial, true)
    render json: {result: 'success', message: t('common.save_success')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end

  def update_ordering
    service_ids = params[:service_ids]
    service_ids.each_with_index do |service_id, index|
      service = Service.find(service_id)
      service.order_id = index + 1
      service.client_id = current_client.id
      service.save
    end
    Service.where(id: service_ids).update_all(client_id: nil) if params[:filter_type] == 'phone'

    render json: {result: 'success', message: t('common.save_success')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end


  private

  def set_service
    @service = Service.find_by(id: params[:id])
  end

  def service_params
    params.require(:service)
          .permit(:name, :duration, :ename, :buffer, :availability, :use_default_availability)
  end

  def set_first_agenda
    @first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
  end

  def set_subscription_plan
    @subscription_plan = session[:current_organization].chargebee_subscription_plan
    @subscription_plan ||= 'free'
  end

  def get_available_hours params_hours
    business_hours = {}
    business_days = params_hours&.keys
    (business_days || []).each do |bday|
      business_hours[bday] = []
      params_hours[bday].each do |working_hour|
        from_hour = working_hour[1]["from"] || working_hour[1][:from]
        to_hour = working_hour[1]["to"] || working_hour[1][:to]
        hours = {'from': from_hour.to_time&.strftime("%H:%M"), 'to': to_hour.to_time&.strftime("%H:%M")}
        business_hours[bday].push(hours.as_json)
      end

    end
    return business_hours
  end

  def get_response_format_example(duration, start_interval, extra_time)
    # make example that response_format is overlapping
    response_format_overlapping_example = ''
    Array(0..3).each do |i|
      overlapping_start_time = i.zero? ? Time.parse("09:00").strftime("%H:%M") : (Time.parse("09:00") + i * 60 * start_interval).strftime("%H:%M")
      response_format_overlapping_example += overlapping_start_time + ', '
    end

    # make example that response_slot is slot
    overlapping_start_time_array = []
    Array(0..((duration + extra_time) * 5 / start_interval)).each do |i|
      overlapping_start_time = i.zero? ? Time.parse("09:00").strftime("%H:%M") : (Time.parse("09:00") + i * 60 * start_interval).strftime("%H:%M")
      overlapping_start_time_array << overlapping_start_time
    end

    slot_start_time = "09:00"
    response_format_slot_example = "09:00, "
    Array(0..3).each do |i| # shot at least 4 examples
      slot_start_time = (Time.parse(slot_start_time) + 60 * duration + 60 * extra_time).strftime("%H:%M")
      loop do
        start_time = overlapping_start_time_array[0]
        break if start_time.nil?
        overlapping_start_time_array.delete(start_time)
        if start_time >= slot_start_time
          response_format_slot_example += start_time + ', '
          slot_start_time = start_time
          break
        end
      end
    end

    {slot_example: response_format_slot_example, overlapping_example: response_format_overlapping_example}
  end

  def fetch_margin_val(margin)
    (100 + margin).to_f / 100
  end

  def fetch_phone_margin(pdata)
    default_margin = pdata.include?(:margin) ? pdata[:margin] : nil
    national_margin = default_margin
    local_margin = default_margin
    mobile_margin = default_margin
    national_margin = pdata[:national] if pdata.include? :national
    local_margin = pdata[:local] if pdata.include? :local
    mobile_margin = pdata[:mobile] if pdata.include? :mobile
    { national: national_margin, local: local_margin, mobile: mobile_margin}
  end
end
