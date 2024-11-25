class ScheduleEventController < ApplicationController
  include IvrsHelper
  include NodeUtils
  include ClientsHelper
  include ApplicationHelper

  skip_before_action :verify_authenticity_token
  before_action :check_ory_session
  before_action :set_calendar_setting, only: [:index, :save_setting, :save_business_hours, :get_event_detail_info]

  layout 'layout'

  def index
    first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
    redirect_to "http://fr.mobminder.com/" and return if first_agenda.type == 'Mobminder'
    redirect_to "http://web.timify.com/" and return if first_agenda.type == 'Timify'

    new_notificaitons = Notification.where(client_id: current_client.id)
    new_notificaitons.destroy_all

    @contacts = current_client.contacts
    @services = current_client.services.active.ordered
    @customers = current_client.customers


    @times = []
    time_start = Time.new(2000, 1, 1)
    time_end = time_start + 1.day
    time_format = @calendar_setting.time_format == "12" ? "%I:%M %p" : "%H:%M"
    [time_start].tap do |array| stime = array.last and array << stime + 5.minutes and
      @times.push({ label: stime.strftime(time_format), value: stime.strftime("%H:%M")}) while array.last < time_end
    end
  end

  def get_time_list
    @times = []
    time_start = Time.new(2000, 1, 1)
    time_end = time_start + 1.day
    time_format = params[:ishour12] == "true" || params[:ishour12] == true ? "%I:%M %p" : "%H:%M"
    [time_start].tap do |array| stime = array.last and array << stime + 5.minutes and
      @times.push({ label: stime.strftime(time_format), value: stime.strftime("%H:%M")}) while array.last < time_end
    end
    render json: {times: @times}
  end

  def get_events
    calendar_ids = []

    from = params[:from].to_time
    to = params[:to].to_time
    from = DateTime.new(from.year, from.month, from.day, 0, 0, 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))
    to = DateTime.new(to.year, to.month, to.day, 0, 0, 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))

    event_params = {}
    event_params.merge!(calendar_ids: calendar_ids)
    event_params.merge!(include_managed: 1, from: from, to: to)

    appointments = []
    classic_agendas.each do |agenda|
      # For ClassicAgenda
      if agenda.cronofy_access_token.present?
        events = agenda.get_events(agenda, from, to)
        events.map{ |event| appointments << event } unless events.nil?
      end
    end

    current_client.application_calendars.where(organization_id: session[:current_organization].id).each do |application_calendar|
      get_application_events(event_params, application_calendar).map{ |event| appointments << event }
    end

    render json: { 'events': appointments, 'timezone': current_client.time_zone }
  end

  def get_application_events(params, application_calendar)
    applcation_calendar_appointments = []
    unless application_calendar.access_token.blank?
      params.merge!(calendar_ids: application_calendar.calendar_id)

      application_calendar_cronofy = current_client.create_cronofy(access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
      events = application_calendar_cronofy.read_events(params) rescue []
      events.each do |appointment|
        # puts appointment
        applcation_calendar_appointments << appointment
      end
    end
    applcation_calendar_appointments
  end

  def get_event_detail_info
    descriptions = params[:description].split("\n")
    index = 0
    description = ""
    unless params[:description][0..10].include? "First name"
      description = params[:description]
      index = 1
    end
    first_name = descriptions[index]
    s = first_name&.split("First name: ")
    first_name = s&.count != 2 ? '' : s[1].strip

    last_name = descriptions[index + 1]
    s = last_name&.split("Last name: ")
    last_name = s&.count != 2 ? '' : s[1].strip

    phone_number = descriptions[index + 2]
    s = phone_number&.split("Phone number: ")
    phone_number = s&.count != 2 ? '' : s[1].strip

    email = descriptions[index + 3]
    s = email&.split("Email: ")
    email = s&.count != 2 ? '' : s[1].strip

    service_name = descriptions[index + 4]
    s = service_name&.split("Service name: ")
    service_name = s&.count != 2 ? '' : s[1].strip

    resource_name = descriptions[index + 5]
    s = resource_name&.split("Resource name: ")
    resource_name = s&.count != 2 ? '' : s[1].strip

    event_id = params[:event_id]
    customer_id = 0
    service_id = 0
    resource_id = 0
    service_duration = @calendar_setting.slot_duration.split(":")[1]
    service_buffer = 0
    appointment = Appointment.find_by_event_id(event_id)
    if appointment
      customer_id = appointment.caller_id
      service_id = appointment.service_id
      resource_id = appointment.resource_id
      unless service_id.nil? || service_id.to_i.zero?
        service = Service.find(service_id)
        service_duration = service.duration
        service_buffer = service.buffer
      end
    end

    reminders = EventTrigger.where(event_id: event_id)

    render json: {description: description, customer: "#{first_name} #{last_name}", service_name: service_name, resource_name: resource_name,
                  customer_id: customer_id, service_id: service_id, resource_id: resource_id, service_duration: service_duration, service_buffer: service_buffer, reminders: reminders }

  end

  def resource_user_email(resource, email_host_body, email_host_subject, type)
    if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
      team_client = Client.find(resource.team_calendar_client_id)
      if team_client
        template_data_team_client = {
          title: type == "confirm" ? t("mails.client_appointment_confirmed.title") : t("mails.confirmation.body_line8"),
          body: email_host_body,
          subject: email_host_subject,
          copyright: t("mails.copyright"),
          reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
        }

        options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_team_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end
    end
  end

  def create
    # local_timezone =  params[:local_timezone].to_i / 60
    # system_timezone = local_timezone < 0 ? 'utc' + local_timezone.to_s : 'utc+' + local_timezone.to_s

    customer_id = params[:customers]
    customer = customer_id.blank? ? nil : Customer.find(customer_id)
    service_id = params[:services]
    service = service_id.blank? ? current_client.services.active.first : Service.find(service_id)
    resource_id = params[:resources]
    resource = resource_id.blank? ? nil : Resource.find(resource_id)

    customer_first_name = customer.nil? ? ' ' : customer.first_name
    customer_last_name = customer.nil? ? ' ' : customer.last_name
    customer_full_name = customer_first_name + customer_last_name

    event_name = params[:calendar_event_name]
    event_description = params[:calendar_event_description] + "\n"

    start_time = "#{params[:calendar_event_start_date]} #{params[:calendar_event_start_time]}".to_datetime
    start_time = DateTime.new(start_time.year, start_time.month, start_time.day, start_time.hour(), start_time.minute(), 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))
    end_time = "#{params[:calendar_event_end_date]} #{params[:calendar_event_end_time]}".to_datetime
    end_time = DateTime.new(end_time.year, end_time.month, end_time.day, end_time.hour(), end_time.minute(), 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))

    if event_description.blank?
      attributes = {
        first_name: customer_first_name,
        last_name: customer_last_name,
        phone_number: customer.nil? ? ' ' : customer.phone_number.nil? ? ' ' : customer.phone_number,
        email: customer.nil? ? ' ' : customer.email.nil? ? ' ' : customer.email,
        service_name: service.nil? ? ' ' : service.name,
        resource_name: resource.nil? ? ' ' : resource.name
      }.compact
      attributes.each{|k,v| event_description += "#{k.to_s.humanize}: #{v} \n"}
    end

    event_id = params[:event_id].blank? ? SecureRandom.hex : params[:event_id]
    event_data = {
      event_id: event_id,
      summary: event_name,
      description: event_description,
      start: start_time.utc.iso8601,
      end: end_time.utc.iso8601,
    }

    if resource.nil?
      resources = current_client.resources.active
    else
      resources = current_client.resources.active.where(id: resource_id)
    end

    if resources.count.zero?
      render json: {result: 'error', message: "There is no any resources" } and return
    else
      resource = resources.first

      resource_token = get_token(current_client, resource.calendar_id)
      if resource_token[:agenda_type] == 'dummy'
        calendar_id = resource.calendar_id
        cronofy = current_client.create_cronofy(access_token: resource_token[:access_token], refresh_token: resource_token[:refresh_token])
        cronofy.upsert_event(calendar_id, event_data)
      else
        main_agenda = classic_agendas.first
        access_toekn = main_agenda.cronofy_access_token
        calendar_id = main_agenda.calendar_id
        main_agenda.create_event(event_data) unless main_agenda.calendar_id.nil?
      end
    end

    email_invitee = current_client.service_notifications.where(service_id: service_id, automation_type: params[:event_id].blank? ? "confirmation_email_invitee" : "rescheduling_email_invitee")
    if email_invitee.count.zero?
      email_invitee_subject = params[:event_id].blank? ? t("mails.confirmation_email_invitee.subject").html_safe : t("mails.rescheduling_email_invitee.subject").html_safe
      email_invitee_body = params[:event_id].blank? ? t("mails.confirmation_email_invitee.body").html_safe : t("mails.rescheduling_email_invitee.body").html_safe
      invitee_include_cancel_link = true
    else
      email_invitee_subject = email_invitee.first.subject
      email_invitee_body = email_invitee.first.text
      invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
    end

    email_host = current_client.service_notifications.where(service_id: service_id, automation_type: params[:event_id].blank? ? "confirmation_email_host" : "rescheduling_email_host")
    if email_host.count.zero?
      use_email_host = false
      email_host_subject = params[:event_id].blank? ? t("mails.confirmation_email_host.subject").html_safe : t("mails.rescheduling_email_host.subject").html_safe
      email_host_body = params[:event_id].blank? ? t("mails.confirmation_email_host.body").html_safe : t("mails.rescheduling_email_host.body").html_safe
    else
      email_host_subject = email_host.first.subject
      email_host_body = email_host.first.text
      use_email_host = email_host.first.use_email_host
    end

    event_date_time = start_time.in_time_zone(current_client.time_zone)
    if invitee_include_cancel_link
      cancel_link = appointment_widget_url(service.ivr.booking_url, event_id: event_id, type: 'cancel')
      reschedule_link = appointment_widget_url(service.ivr.booking_url, event_id: event_id, type: 'schedule')
    else
      cancel_link = ''
      reschedule_link = ''
    end

    email_body = email_host_body % {full_name: customer_full_name,
                                    first_name: customer_first_name,
                                    last_name: customer_last_name,
                                    resource_name: resource&.name,
                                    event_name: service&.name,
                                    event_date: l(event_date_time.to_date, format: :long, locale: service.ivr.voice_locale),
                                    event_time: event_date_time.strftime("%I:%M %p"),
                                    event_day: event_date_time.strftime("%A")}
    email_host_body = email_body

    template_data_client = {
      title: params[:event_id].blank? ? t("mails.client_appointment_confirmed.title") : t("mails.confirmation.body_line8"),
      body: email_body,
      subject: email_host_subject,
      copyright: t("mails.copyright"),
      reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
    }

    email_body = email_invitee_body % {full_name: customer_full_name,
                                       first_name: customer_first_name,
                                       last_name: customer_last_name,
                                       resource_name: resource&.name,
                                       event_name: service&.name,
                                       event_date: l(event_date_time.to_date, format: :long, locale: service.ivr.voice_locale),
                                       event_time: event_date_time.strftime("%I:%M %p"),
                                       event_day: event_date_time.strftime("%A")}

    template_data_invitee = {
      title: params[:event_id].blank? ? t("mails.client_appointment_confirmed.title") : t("mails.confirmation.body_line8"),
      body: email_body,
      subject: email_invitee_subject,
      cancel_link: cancel_link,
      reschedule_link: reschedule_link,
      copyright: t("mails.copyright"),
      reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
    }

    if params[:event_id].blank?
      appointment = Appointment.new(caller_id: customer.nil? ? nil : customer.id, caller_name: customer.nil? ? '' : customer_full_name,
                       time: start_time, tropo_session_id: nil, client_id: current_client.id, source: 'Schedule Booking', ivr_id: current_client.ivrs.first.id,
                      service_id: service ? service.id : nil, resource_id: resource ? resource.id : nil, event_id: event_id, status: "Confirmed")

      if appointment.save
        if use_email_host
          options = { to: current_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

          resource_user_email(resource, email_host_body, email_host_subject, "confirm")
        end

        if customer && customer.email.present?
          options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: current_client.email, reply_to_name: current_client.full_name }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
        end

        render json: {result: 'success', message: t('schedule_event.add_event.added_success') } and return
      else
        render json: {result: 'error', message: appointment.errors.full_messages } and return
      end
    else
      appointment = Appointment.where(event_id: params[:event_id])
      rescheduled_count = appointment.first.rescheduled_count ? appointment.first.rescheduled_count + 1 : 1
      appointment.update_all(caller_id: customer.nil? ? nil : customer.id, caller_name: customer.nil? ? '' : customer.full_name,
                      service_id: service ? service.id : nil, resource_id: resource ? resource.id : nil, time: start_time, status: "Rescheduled", rescheduled_count: rescheduled_count)

      if appointment
        if use_email_host
          options = { to: current_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

          resource_user_email(resource, email_host_body, email_host_subject, "reschedule")
        end

        if customer && customer.email.present?
          options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: current_client.email, reply_to_name: current_client.full_name }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
        end

        render json: {result: 'success', message: t('schedule_event.add_event.updated_success') } and return
      else
        render json: {result: 'error', message: appointment.errors.full_messages } and return
      end
    end

    if service_id.present?
      helpers.create_event_trigger(service, resource,
           {'id': event_data[:event_id], 'summary': event_name, 'start': start_time.utc.iso8601, 'end': end_time.utc.iso8601},
           access_token, calendar_id)
    else
      begin
        transitions = []
        trigger_times = params[:customer][:trigger_time]
        trigger_durations = params[:customer][:trigger_duration]
        trigger_times.each_with_index do |time, index|
          transition_option = { "before": "event_start", "offset": {"minutes": time.to_i} } if trigger_durations[index] == 'minutes'
          transition_option = { "before": "event_start", "offset": {"hours": time.to_i} } if trigger_durations[index] == 'hours'
          transition_option = { "before": "event_start", "offset": {"minutes": time.to_i * 24 * 60} } if trigger_durations[index] == 'days' # convert day to minutes
          transitions.push(transition_option)
        end

        headers = {
          "Content-Type"  => "application/json",
          "Authorization" => "Bearer " + access_token
        }
        query = {
          "event_id": event_data[:event_id],
          "summary": event_name,
          "start": start_time.utc.iso8601,
          "end": end_time.utc.iso8601,
          "subscriptions": [
            {
              "type": "webhook",
              "uri": get_event_trigger_path,
              # "uri": "https://c405-23-105-155-2.ngrok.io/event_trigger?locale=en",
              "transitions": transitions
            }
          ]
        }

        api_path = ApplicationController.helpers.get_api_center_url(current_client.data_server) + '/v1/calendars/' + calendar_id + '/events'
        response = HTTParty.post(api_path, { headers: headers, body: JSON.generate(query) })
        if response.nil?
          trigger_times.each_with_index do |time, index|
            event_trigger = EventTrigger.new(event_id: event_data[:event_id], trigger_id: '', offset_time: time, offset_duration: trigger_durations[index])
            event_trigger.save
          end
        end
      rescue => e
        puts "creation event trigger failure (calendar page) ~~~~~~~~~~~~" + e.message
      end
    end

  rescue Exception => e
    puts e
    render json: {result: 'error', message: e.message }
  end

  def delete_event
    event_id = params[:event_id]
    from = params[:from].to_time
    to = params[:to].to_time
    from = DateTime.new(from.year, from.month, from.day, 0, 0, 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))
    to = DateTime.new(to.year, to.month, to.day, 0, 0, 0, Time.now.in_time_zone(current_client.time_zone).strftime('%z'))

    event_params = {}
    event_params.merge!(include_managed: 1, from: from, to: to)

    appointments = []
    classic_agendas.each do |agenda|
      if agenda.cronofy_access_token.present?
        events = agenda.get_events(agenda, from, to)
        events.map { |event| appointments << event } unless events.nil?
      end
      calendar_id = ''
      appointments.each do |appointment|
        calendar_id = appointment['calendar_id'] if appointment['event_id'] == event_id && calendar_id.blank?
      end
      agenda.delete_event(calendar_id,  event_id) if calendar_id.present?
    end

    current_client.application_calendars.each do |application_calendar|
      unless application_calendar.access_token.blank?
        calendar_id = ''

        application_calendar_cronofy = current_client.create_cronofy(access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
        appointments = application_calendar_cronofy.read_events(event_params) rescue []
        appointments.each do |appointment|
          calendar_id = appointment['calendar_id'] if appointment['event_id'] == event_id && calendar_id.blank?
        end
        application_calendar_cronofy.delete_event(calendar_id, event_id) if calendar_id.present?
      end
    end

    appointment = Appointment.find_by(event_id: event_id)
    if appointment
      event_name = appointment.service.name
      event_date_time = appointment.time.in_time_zone(current_client.time_zone)
      event_date = I18n.localize(event_date_time.to_date, format: :long, locale: appointment.ivr.voice_locale)
      event_time = event_date_time.strftime("%I:%M %p")
      event_day = event_date_time.strftime("%A")
      customer = Customer.find_by(id: appointment.caller_id&.to_i)
      resource = Resource.find_by(id: appointment.resource_id)

      customer_first_name = customer.nil? ? ' ' : customer.first_name
      customer_last_name = customer.nil? ? ' ' : customer.last_name
      customer_full_name = customer_first_name + customer_last_name

      email_invitee_notification = ServiceNotification.where(service_id: appointment.service_id, automation_type: 'cancellation_email_invitee')
      email_invitee_subject = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.subject') : email_invitee_notification.first.subject
      email_invitee_body = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.body') : email_invitee_notification.first.text
      email_invitee_body = email_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                 first_name: customer_first_name, last_name: customer_last_name, full_name: customer_full_name, resource_name: resource&.name}

      email_host_notification = ServiceNotification.where(service_id: appointment.service_id, automation_type: 'cancellation_email_host')
      email_host_subject = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.subject') : email_host_notification.first.subject
      email_host_body = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.body') : email_host_notification.first.text
      email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                           first_name: customer_first_name, last_name: customer_last_name, full_name: customer_full_name, resource_name: resource&.name}
      use_email_host = email_host_notification.count.zero? ? false : email_host_notification.first.use_email_host

      if use_email_host
        template_data_client = {
          title: t("mails.cancellation_email_invitee.title"),
          body: email_host_body,
          subject: email_host_subject,
          copyright: t("mails.copyright"),
          reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
        }
        options = { to: current_client.email, template_id: ENV['VOXIPLAN_CLIENT_CANCEL'], template_data: template_data_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

        if resource&.calendar_type == "team_calendar" and resource&.team_calendar_client_id and resource&.team_calendar_client_id != ""
          team_client = Client.find(resource&.team_calendar_client_id)
          if team_client
            team_client_email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                             first_name: customer_first_name, last_name: customer_last_name, full_name: customer_full_name, resource_name: resource&.name}

            template_data_team_client = {
              title: t("mails.cancellation_email_invitee.title"),
              body: team_client_email_host_body,
              subject: email_host_subject,
              copyright: t("mails.copyright"),
              reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
            }

            options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_CANCEL'], template_data: template_data_team_client }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
          end
        end
      end

      template_data_invitee = {
        title: t("mails.cancellation_email_invitee.title"),
        body: email_invitee_body,
        subject: email_invitee_subject,
        copyright: t("mails.copyright"),
        reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
      }
      if customer && customer.email.present?
        options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_CANCEL'], template_data: template_data_invitee, reply_to_email: current_client.email, reply_to_name: current_client.full_name }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end

      appointment.answers.destroy_all
      # appointment.destroy
      appointment.update_columns(status: "Cancelled")
    end

    EventTrigger.where(event_id: event_id).destroy_all
    render json: {result: 'success', message: t('schedule_event.add_event.deleted_success') }
  end

  def save_setting
    @calendar_setting.slot_duration = params[:slotDuration]
    @calendar_setting.snap_duration = params[:snapDuration]
    @calendar_setting.min_time = params[:slotMinTime]
    @calendar_setting.max_time = params[:slotMaxTime]
    @calendar_setting.hidden_days = params[:weekends].join(',')
    @calendar_setting.first_day = params[:firstDay]
    @calendar_setting.time_format = params[:time_format]
    @calendar_setting.save

    render json: {result: 'success', message: t('common.save_success')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end

  def save_business_hours
    availability_hours = availabilities_hours(params[:business_hours])
    @calendar_setting.availabilities = availability_hours
    @calendar_setting.save

    render json: {result: 'success', message: t('common.save_success')}
  rescue => e
    render json: {result: 'error', message: e.message}
  end

  private

  def classic_agendas
    current_client.agenda_apps.where(type: 'ClassicAgenda')
  end

  def set_calendar_setting
    @calendar_setting = current_client.calendar_setting
  end
end
