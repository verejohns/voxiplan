class ChatController < ApplicationController
  include ApplicationHelper

  layout :resolve_layout

  protect_from_forgery except: :appointment
  invisible_captcha only: [:book_appointment], honeypot: :booking_url, on_spam: :send_notification_email
  before_action :set_ivr, only: [:fetch_available_slots, :fetch_available_slots_for_schedule, :validate_customer, :create_customer, :book_appointment, :cancel_appointment, :book_appointment_for_schedule]
  # before_action :check_ory_session, only: [:send_sms, :sms]

  def index
    @ivr = Ivr.find_by_booking_url(params[:id]) if params[:id].present?
    @uid = @ivr.uid+'@voxi.ai' if @ivr
  end

  def send_sms
  	phone = params[:phone]
  	msg_text = params[:msg_body]
  	if current_ivr.confirmation_sms?
      if is_valid_mobile(phone)
        sms = create_sms(phone,msg_text)
        telephony = telephony_create(telephony_name)
        telephony.send_sms(sms.id) if sms.persisted?
        redirect_to sms_path, notice: 'SMS sent successfuly.' and return
      end
    end
    redirect_to sms_path, notice: 'SMS cannot be sent.' and return
  end

  def sms
  end

  def appointment
    response.headers.delete "X-Frame-Options"

    @host = request.base_url.gsub('https://', '')
    @host = @host.gsub('http://', '')
    @host = 'Voxiplan' if @host.downcase == 'app.voxiplan.com'
    @host = 'Voxi.ai' if @host.downcase == 'app.voxi.ai'

    @ivr = Ivr.find_by_booking_url(params[:id]) if params[:id].present?
    @id_auth = @ivr.present? && ((@ivr.client.agenda_apps.count.zero? && ApplicationCalendar.where(client_id: @ivr.client.id).count > 0) || (@ivr.client.agenda_apps.count > 0 && @ivr.client.agenda_apps.first.type == 'ClassicAgenda'))

    redirect_to root_path, alert: "The IVR isn't exist" and return unless @ivr

    if @ivr.client.agenda_apps.count > 0 && @ivr.client.agenda_apps.first.type == 'ClassicAgenda'
      classic_resources = @ivr.client.resources.where(ivr_id: @ivr.id)
      unless classic_resources.count.zero?
        # @id_auth = false if classic_resources[0].application_calendar_id.nil?
      end
    end

    @dummy_data = @ivr.client.agenda_apps.count.zero?
    @time_zone = Time.zone.name

    if @ivr.client.agenda_apps.count.zero?
      services_list = @ivr.client.services.where(ivr_id: @ivr.id)
    else
      if @ivr.client.agenda_apps.first.type == 'ClassicAgenda'
        services_list = @ivr.client.services.where(ivr_id: @ivr.id)
      else
        services_list = @ivr.services.where(ivr_id: @ivr.id, agenda_type: @ivr.client.agenda_apps.first.type)
      end
    end

    @services_list = services_list.select{|s| s.enabled && (s.preference["widget_enabled"] == "true" || s.preference["widget_enabled"] == true)}#.sort_by{ |k| k.order_id}

    resource_list = @ivr.client.resources.active.where(ivr_id: @ivr.id)

    @resources_list = []
    resource_list.each do |r|
      resource_enabled = true

      if @services_list.count == 1
        is_default_service = false

        r.services.each do |service|
          if service.id == @services_list[0].id
            is_default_service = true
            break
          end
        end

        resource_enabled = is_default_service
      end

      @resources_list.push(r) if r.services.count && resource_enabled
    end

    @widget_tz = @ivr.preference['widget_tz'] || '-'
    @widget_time_format = @ivr.preference['widget_time_format'] || '-'
    @widget_language = @ivr.preference['widget_language'] || '-'
    @widget_filter = @ivr.preference['widget_filter'] || "true"
    @widget_title = @ivr.preference['widget_title'] || ''
    @future_days = @ivr.preference['widget_future_days'] || ''
    @level1_dropdown = @ivr.preference["widget_level1_dropdown"] || 'Custom Order'
    @default_resource = @ivr.preference["widget_dropdown_default_resource"] || 'serviceFirst'
    @appointment_type = params[:type]
    @event_id = params[:event_id].blank? ? nil : params[:event_id]

    @appointment_timezone, @appointment_name, @appointment_duration, @appointment_time = ''
    @appointment_customer_name, @appointment_customer_firstname, @appointment_customer_lastname, @appointment_customer_email, @appointment_customer_phone = ''
    @appointment_service_id, @appointment_resource_id, @appointment_customer_id = 0
    @appointment_answers = {}

    if @appointment_type == 'schedule'
      appointments = Appointment.where(event_id: @event_id)
      if appointments.count.zero?
        @appointment_type = 'invalid_cancel_event'
      else
        appointment = appointments.first
        @appointment_status = appointment.status.downcase
        @appointment_name = appointment.service.name
        @appointment_service_id = appointment.service_id
        @appointment_resource_id = appointment.resource_id

        customer = Customer.where(id: appointment.caller_id&.to_i)
        @appointment_customer_firstname = customer&.first&.first_name
        @appointment_customer_lastname = customer&.first&.last_name
        @appointment_customer_name = customer&.first&.first_name + ' ' + customer&.first&.last_name
        @appointment_customer_email = customer&.first&.email
        @appointment_customer_phone = customer&.first&.phone_number
        @appointment_answers = appointment.answers
        @appointment_customer_id = customer&.first.id
      end
    end

    if @appointment_type == 'cancel'
      appointments = Appointment.where(event_id: @event_id)
      if appointments.count.zero?
        @appointment_type = 'invalid_cancel_event'
      else
        appointment = appointments.first
        @appointment_status = appointment.status.downcase
        @appointment_timezone = @ivr.client.time_zone
        @appointment_name = appointment.service.name
        @appointment_duration = appointment.service.duration
        @appointment_start_time = appointment.time.utc
        @appointment_end_time = @appointment_start_time + @appointment_duration * 60

        start_time = appointment.time.in_time_zone(@timezone)
        end_time = start_time + @appointment_duration * 60
        # @appointment_time = start_time.strftime("%I:%M %P") + ' - ' + end_time.strftime("%I:%M %P") + ", " + start_time.strftime("%A")  + ", " + l(start_time.to_date, format: :long, locale: @ivr.voice_locale)
        @appointment_time = start_time

        customer = Customer.where(id: appointment.caller_id&.to_i)
        @appointment_customer_name = customer&.first&.first_name + ' ' + customer&.first&.last_name
        @appointment_customer_email = customer&.first&.email
        @appointment_customer_phone = customer&.first&.phone_number
      end
    end
  end

  def linked_services_or_resources
    @linked_data = []
    @linked_data = Resource.find(params[:id]).services.pluck(:id) if params[:type] == 'resource'
    @linked_data = Service.find(params[:id]).resources.pluck(:id) if params[:type] == 'service'

    render json: {linked_data: @linked_data}, status: 200
  end

  def linked_questions
    @questions_data = []
    questions = Question.where("service_id = ? and answer_type != ?", params[:service_id], 'mandatory')
    questions.active.each { |record| @questions_data << {'text' => record.text, 'answer_type' => record.answer_type, 'mandatory': record.mandatory, 'options': record.question_options.pluck(:text)} }

    render json: {questions_data: @questions_data}, status: 200
  end

  def fetch_available_slots_for_schedule
    start_after_time = slots_after_time(params[:start_time])
    params[:start_time] = Time.parse(start_after_time.to_s) > Time.parse(params[:start_time]) ? Time.parse(start_after_time.to_s) : Time.parse(params[:start_time])
    params[:first_start_date] = params[:start_time]

    # from = ActiveSupport::TimeZone['UTC'].parse(params[:start_time])
    # to = params[:mobile_view] ? ActiveSupport::TimeZone['UTC'].parse(params[:start_time]) + 1.days : ActiveSupport::TimeZone['UTC'].parse(params[:start_time]) + 7.days
    # to_calendar = ActiveSupport::TimeZone['UTC'].parse(params[:start_time]) + 30.days
    from = Time.parse(params[:start_time].to_s).utc.iso8601
    to = params[:mobile_view] ? (DateTime.parse(from) + 1.days).utc.iso8601 : (DateTime.parse(from) + 7.days).utc.iso8601
    to_calendar = (DateTime.parse(from) + 30.days).utc.iso8601

    slots = []
    slots_for_calendar = []
    @ivr.client.agenda_apps.each do |agenda|
      # For ClassicAgenda
      if agenda.type == 'ClassicAgenda' && agenda.cronofy_access_token.present?
        # slots = agenda.free_slots_for_schedule(nil, from, to, 'agenda')
        # slots_for_calendar = agenda.free_slots_for_schedule(nil, from, to_calendar, 'agenda')
        slots = agenda.free_slots(nil, from, {service_id: params[:service_id], resource_id: params[:resource_id], end_time: to, time_slot: params[:tslot]})
        slots_for_calendar = agenda.free_slots(nil, from, {service_id: params[:service_id], resource_id: params[:resource_id], end_time: to_calendar, time_slot: params[:tslot]})
      end
    end

    if @ivr.client.agenda_apps.count.zero?
      agenda = DummyAgenda::new
      # slots = agenda.free_slots_for_schedule(nil, from, to, 'cronofy')
      # slots_for_calendar = agenda.free_slots_for_schedule(nil, from, to_calendar, 'cronofy')
      slots = agenda.free_slots(nil, from, {service_id: params[:service_id], resource_id: params[:resource_id], end_time: to, time_slot: params[:tslot]})
      slots_for_calendar = agenda.free_slots(nil, from, {service_id: params[:service_id], resource_id: params[:resource_id], end_time: to_calendar, time_slot: params[:tslot]})
    end

    slots = [] if slots.nil?
    slots = slots.sort_by { |k| k["start"] }
    slots_for_calendar = slots_for_calendar.sort_by { |k| k["start"] }

    slot_groups =  slots.group_by{|e| e['start']}
    slots = slot_groups.map do |_, slots| {"start" => slots[0]['start'], "finish" =>slots[0]['finish'], "resource_id" => slots.map{|s| s['resource_id']}} end

    slot_cal_groups =  slots_for_calendar.group_by{|e| e['start']}
    slots_for_calendar = slot_cal_groups.map do |_, slots| {"start" => slots[0]['start'], "end" =>slots[0]['end'], "resource_id" => slots.map{|s| s['resource_id']}} end

    days = slots.map{|c| DateTime.parse(c["start"].to_s).strftime("%Y-%m-%d")} if slots
    days_calendar = slots_for_calendar.map{|c| DateTime.parse(c["start"].to_s).strftime("%Y-%m-%d")} if slots_for_calendar

    avail_days = days.uniq{|x| x} if days
    avail_days_calendar = days_calendar.uniq{|x| x} if days_calendar

    times_list = {}
    if avail_days.present?
      avail_days.each do |d|
        times_list.store(d.to_s, times_in_day(slots,Date.parse(d)).to_s)
      end
    end

    render json: {
      slots: slots,
      days: avail_days,
      times_list: times_list,
      buffer: 0,
      duration: Service.find(params[:service_id]).duration,
      off_days: [],
      start_calendar:  Date.parse(params[:first_start_date].to_s).strftime("%Y-%m-%d"),
      calendar_days: avail_days_calendar,
      next_available_slot: (next_available_slot_for_schedule(from) if @avail_days.blank?)
    }, status: 200
  end

  def fetch_available_slots
    return render json: {error_message: 'No ivr is found!'}, status: 500 unless @ivr
    act_start_dt = params[:start_time]
    params[:start_time] = next_availability_mobile(params[:start_time], params[:service_id], params[:resource_id]) if params[:check_next_on_mobile]
    if params[:widget_load]
      start_after_time = slots_after_time(act_start_dt)
      params[:start_time] = Time.parse(start_after_time.to_s) > Time.parse(params[:start_time]) ? Time.parse(start_after_time.to_s) : Time.parse(params[:start_time])
      params[:first_start_date] = params[:start_time]
    end
    begin
      service = Service.find(params[:service_id])
      resource = Resource.find(params[:resource_id])

      @start_calendar = Date.parse(params[:first_start_date].to_s).strftime("%Y-%m-%d")
      start_time = Time.parse(params[:start_time].to_s).utc
      end_time = start_time + 7.days
      end_time = start_time + 1.days if params[:mobile_view]
      end_time_calendar = start_time + 30.days

      start_time = start_time.iso8601
      end_time = end_time.iso8601
      end_time_calendar = end_time_calendar.iso8601

      # end_time_calendar = (DateTime.parse(start_time)+30.days).utc.iso8601
      @slots = []
      @slots_for_calendar = []

      agenda = @ivr.client.agenda_apps.count.zero? ? DummyAgenda.new : @ivr.client.agenda_apps.first
      @slots = agenda.free_slots(nil,start_time,{service_id: params[:service_id], resource_id: params[:resource_id], end_time: end_time, time_slot: params[:tslot]})
      begin
        @slots_for_calendar = agenda.free_slots(nil,start_time,{service_id: params[:service_id], resource_id: params[:resource_id], end_time: end_time_calendar, time_slot: params[:tslot]})
      rescue => e
        puts e
        @slots_for_calendar = []
      end

      @slots = @slots.sort_by { |k| k["start"] }
      @slots_for_calendar = @slots_for_calendar.sort_by { |k| k["start"] }
      slot_groups =  @slots.group_by{|e| e['start']}
      @slots = slot_groups.map do |_, slots| {"start" => slots[0]['start'], "finish" =>slots[0]['finish'], "resource_id" => slots.map{|s| s['resource_id']}} end
      slot_cal_groups =  @slots_for_calendar.group_by{|e| e['start']}
      @slots_for_calendar = slot_cal_groups.map do |_, slots| {"start" => slots[0]['start'], "end" =>slots[0]['end'], "resource_id" => slots.map{|s| s['resource_id']}} end
      days = @slots.map{|c| DateTime.parse(c["start"].to_s).strftime("%Y-%m-%d")} if @slots
      days_calendar = @slots_for_calendar.map{|c| DateTime.parse(c["start"].to_s).strftime("%Y-%m-%d")} if @slots_for_calendar
      @avail_days = days.uniq{|x| x} if days
      @avail_days_calendar = days_calendar.uniq{|x| x} if days_calendar
      @times_list = {}
      if @avail_days.present?
        @avail_days.each do |d|
          @times_list.store(d.to_s, times_in_day(@slots,Date.parse(d)).to_s)
        end
      end

      off_array = []
      if service.random_resource_widget
        service.resources.each do |r|
          off_array = off_array +  off_days(r)
        end
      else
        off_array = off_days(resource)
      end
      @off_days = [0, 1, 2, 3, 4, 5, 6] - off_array
    rescue => e
      return render json: {error_message: e}, status: 500
    end

    render json: {
      slots: @slots,
      days: @avail_days,
      times_list: @times_list,
      buffer: service.buffer,
      duration: service.duration,
      off_days: @off_days,
      start_calendar: @start_calendar,
      calendar_days: @avail_days_calendar,
      next_available_slot: (next_available_slot(start_time, params[:service_id], params[:resource_id]) if @avail_days.blank?)
    }, status: 200
  end

  def off_days(resource)
    mapping = {'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6}

    availability =
      if resource.use_default_availability && resource.ivr
        resource.ivr.client.agenda_apps.count.zero? ? BusinessHours::DEFAULT_AVAILABILITY.transform_keys(&:to_s) : resource.ivr.client.agenda_apps.first.default_resource_availability
      else
        resource.availability
      end

    availability.keys.map { |x| mapping.fetch(x, x) }
  end

  def validate_customer
    # phone_st = false
    if params[:email]
      customer_email = params[:email]
      return render json: {email_status: false}, status: 200 if is_invalid_email(customer_email)
      customers = @ivr.client.customers.where(email: customer_email).order(id: :desc)
      customer = customers.count.zero? ? nil : customers.first
    end

    return render json: {customer_data: customer}, status: 200 if customer
    if params[:phone]
      params[:phone] = Phonelib.parse(params[:phone]).e164
      customer = @ivr.client.customers.find_by(phone_number: params[:phone])
      contact = @ivr.client.contacts.find_by(phone: params[:phone])
      # contact = @ivr.client.customers.find{ |n| n.contacts.find_by(phone: params[:phone])} if contact.blank?
      # phone_st = is_valid_mobile(params[:phone])
      return render json: {customer_data: (customer || contact.customer)}, status: 200 if (customer || (contact != nil && contact.customer))
    end
    return render json: {phone_status: true}, status: 200
  end

  def get_mandatory_question
    question = Question.where(service_id: params[:service_id], answer_type: 'mandatory').first
    render json: { mandatory_question: question[:text] }
  rescue => e
    puts e.message
    render json: { mandatory_question: 'first_lastname' }
  end

  def create_customer
    customer1 = @ivr.client.customers.find_by(phone_number: params[:phone_number])
    customer2 = @ivr.client.customers.find_by(phone_number: Phonelib.parse(params[:phone_number]).e164)
    customer3 = @ivr.client.customers.find_by(email: params[:email])
    if customer1 || customer2
      customer = Customer.find(customer1.id) if customer1
      customer = Customer.find(customer2.id) if customer2
      customer.email = params[:email]
      customer.first_name = params[:first_name]
      customer.last_name = params[:last_name]
      new_customer = false
    elsif customer3 && (customer3.first_name.blank? || customer3.first_name == 'X.')
      customer3.first_name = params[:first_name]
      customer3.last_name = params[:last_name]
      customer = customer3
      new_customer = false
    else
      customer = @ivr.client.customers.new(customer_params)
      new_customer = true
    end

    if customer.save
      if new_customer
        customer.contacts.create(phone: Phonelib.parse(params[:phone_number]),client_id: @ivr.client.id)
        CreateCustomerOnAgendaJob.perform_later(customer.id, @ivr.client.agenda_apps.first.id) if customer.created_on_agenda && @ivr.client.agenda_apps.count > 0
        if @ivr.client.agenda_apps.count.zero?
          customer.eid = customer.id
          customer.created_on_agenda = true
          customer.save
        end
      end

      render json: customer.to_json(:include => [:contacts]) , status: 200
    else
      render json: customer.errors, status: 422
    end
  end

  def update_customer
    customer = Customer.find(params[:customer_id])
    customer.email = params[:email]
    if customer.save
      render json: {message: 'Customer updated successfuly!'} , status: 200
    else
      render json: {message: 'Customer can not be updated!'}, status: 422
    end
  end

  def book_appointment_for_schedule
    local_timezone =  params[:local_timezone].to_i / 60
    system_timezone = local_timezone < 0 ? 'utc' + local_timezone.to_s : 'utc+' + local_timezone.to_s

    event_id = params[:event_id]
    event_name = params[:event_name]
    event_description = " "
    first_name = params[:first_name]
    last_name = params[:last_name]

    # start_time = params[:start_time].to_time(system_timezone)
    # end_time = params[:end_time].to_time(system_timezone)

    st_time = Time.at(Time.parse(params[:start_time])).in_time_zone('UTC')
    en_time = Time.at(Time.parse(params[:end_time])).in_time_zone('UTC')

    service = Service.find_by(id: params[:service_id])
    resource = Resource.find_by(id: params[:resource_id])
    client = Client.find(@ivr.client_id)

    attributes = {
      first_name: first_name,
      last_name: last_name,
      phone_number: params[:phone_number],
      email: params[:email],
      service_name: service.name || ' ',
      resource_name: resource.name || ' ',
      questions: params[:question_details] ? JSON.parse(params[:question_details]) : nil,
    }.compact
    attributes.each{|k,v| event_description += "#{k.to_s.humanize}: #{v} \n"}

    event_data = {
      event_id: event_id,
      summary: event_name,
      description: event_description,
      start: Time.utc(st_time.year, st_time.month, st_time.day, st_time.hour, st_time.min),
      end: Time.utc(en_time.year, en_time.month, en_time.day, en_time.hour, en_time.min),
    }

    access_token = AgendaApp.where('conflict_calendars like ? ', "%#{resource.calendar_id}%").count > 0 ? AgendaApp.where('conflict_calendars like ? ', "%#{resource.calendar_id}%").first.cronofy_access_token : ApplicationCalendar.find_by_calendar_id(resource.calendar_id).access_token

    if resource.calendar_id.nil?
      cronofy = resource.client.create_cronofy(server_region: nil, access_token: access_token, refresh_token: nil)
      cronofy.upsert_event(resource.application_calendar_id, event_data)
    else
      cronofy = resource.client.create_cronofy(server_region: nil, access_token: access_token, refresh_token: resource.application_refresh_token)
      cronofy.upsert_event(resource.calendar_id.presence || client.default_resource.calendar_id, event_data)
    end

    email_invitee = client.service_notifications.where(service_id: params[:service_id], automation_type: "rescheduling_email_invitee")
    if email_invitee.count.zero?
      email_invitee_subject = t("mails.rescheduling_email_invitee.subject").html_safe
      email_invitee_body = t("mails.rescheduling_email_invitee.body").html_safe
      invitee_include_cancel_link = true
    else
      email_invitee_subject = email_invitee.first.subject
      email_invitee_body = email_invitee.first.text
      invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
    end

    email_host = client.service_notifications.where(service_id: params[:service_id], automation_type: "rescheduling_email_host")
    if email_host.count.zero?
      use_email_host = false
      email_host_subject = t("mails.rescheduling_email_host.subject").html_safe
      email_host_body = t("mails.rescheduling_email_host.body").html_safe
    else
      email_host_subject = email_host.first.subject
      email_host_body = email_host.first.text
      use_email_host = email_host.first.use_email_host
    end

    cancel_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: event_id, type: 'cancel') : ''
    reschedule_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: event_id, type: 'schedule') : ''
    event_date_time = st_time.in_time_zone(@ivr.client.time_zone)

    if use_email_host
      email_body = email_host_body % {full_name: params[:first_name] + ' '+ params[:last_name],
                                      first_name: params[:first_name],
                                      last_name: params[:last_name],
                                      resource_name: resource&.name,
                                      event_name: service&.name,
                                      event_date: l(event_date_time.to_date, format: :long, locale: @ivr.voice_locale),
                                      event_time: event_date_time.strftime("%I:%M %p"),
                                      event_day: event_date_time.strftime("%A")}

      template_data_client = {
        title: t("mails.confirmation.body_line8"),
        body: email_body,
        subject: email_host_subject,
        copyright: t("mails.copyright"),
        reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
      }

      options = { to: @ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
      SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

      resource_user_email(resource, email_body, email_host_subject, "reschedule")
    end

    email_body = email_invitee_body % {full_name: params[:first_name] + ' '+ params[:last_name],
                                       first_name: params[:first_name],
                                       last_name: params[:last_name],
                                       resource_name: resource&.name,
                                       event_name: service&.name,
                                       event_date: l(event_date_time.to_date, format: :long, locale: @ivr.voice_locale),
                                       event_time: event_date_time.strftime("%I:%M %p"),
                                       event_day: event_date_time.strftime("%A")}

    template_data_invitee = {
      title: t("mails.confirmation.body_line8"),
      body: email_body,
      subject: email_invitee_subject,
      cancel_link: cancel_link,
      reschedule_link: reschedule_link,
      copyright: t("mails.copyright"),
      reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
    }

    options = { to: params[:email], template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: @ivr.client.email, reply_to_name: @ivr.client.full_name }
    SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

    appointment = Appointment.find_by(event_id: params[:event_id])
    rescheduled_count = appointment.rescheduled_count ? appointment.rescheduled_count + 1 : 1
    result = appointment.update_attributes(caller_id: params[:customer_id], time: Time.at(Time.parse(params[:start_time])), status: "Rescheduled", rescheduled_count: rescheduled_count)
    if result
      appointment.answers.destroy_all
      if params[:question_details]
        JSON.parse(params[:question_details]).each do |q|
          Answer.create(question_text: q['question'], text: q['answer'], question_type: q['question_type'], customer_id: params[:customer_id], appointment_id: appointment.id)
        end
      end
      render json: {result: 'success', message: t('schedule_event.add_event.updated_success') }
    else
      render json: {result: 'error', message: result.errors.full_messages }
    end

  rescue Exception => e
    puts e
  end

  def resource_user_email(resource, email_body, email_host_subject, type)
    if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
      team_client = Client.find(resource.team_calendar_client_id)
      if team_client
        template_data_team_client = {
          title: type == "confirm" ? t("mails.client_appointment_confirmed.title") : t("mails.confirmation.body_line8"),
          body: email_body,
          subject: email_host_subject,
          copyright: t("mails.copyright"),
          reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
        }

        options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_team_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end
    end
  end

  def book_appointment
    return render json: {message: 'You have reached your appointments limit!'}, status: 401 if max_allowed_appointments(params[:customer_id], params[:resource_id])
    return render json: {message: 'No slot is selected for appointment to book!'}, status: 401 unless params[:slot_start] && params[:slot_end]

    st_time = Time.at(Time.parse(params[:slot_start])).in_time_zone('UTC')
    en_time = Time.at(Time.parse(params[:slot_end])).in_time_zone('UTC')
    pre_confirmation = Service.find_by(id: params[:service_id])&.preference["pre_confirmation"] == "true"
    caller_id = Customer.find(params[:customer_id]).phone_number.presence || Customer.find(params[:customer_id]).contacts.try(:first).try(:phone).presence
    opts = {
            resource: params[:resource_id],
            service: params[:service_id],
            customer_id: params[:customer_id],
            start: Time.utc(st_time.year, st_time.month, st_time.day, st_time.hour, st_time.min),
            end: Time.utc(en_time.year, en_time.month, en_time.day, en_time.hour, en_time.min),
            questions: params[:question_details] ? JSON.parse(params[:question_details]) : nil,
            evt_id: ""
          }
    begin
      agenda = @ivr.client.agenda_apps.count.zero? ? DummyAgenda::new : @ivr.client.agenda_apps.first
      agenda.create_appointment(opts)
      appointment = Appointment.create(caller_id: Customer.find(params[:customer_id]).id, caller_name: Customer.find(params[:customer_id]).full_name,
                      time: Time.at(Time.parse(params[:slot_start])), tropo_session_id: nil, client_id: @ivr.client.id, 
                      source: 'Booking Widget', ivr_id: @ivr.id, resource_id: params[:resource_id], service_id: params[:service_id],
                      event_id: opts[:evt_id], status: pre_confirmation ? "Pending" : "Confirmed")
      begin
        if params[:question_details]
          JSON.parse(params[:question_details]).each do |q|
            Answer.create(question_text: q['question'], text: q['answer'], question_type: q['question_type'], customer_id: params[:customer_id], appointment_id: appointment.id)
          end
        end

        client = Client.find(@ivr.client_id)
        resource = Resource.find(params[:resource_id])
        service = Service.find(params[:service_id])
        customer = Customer.find(params[:customer_id])

        email_invitee = client.service_notifications.where(service_id: params[:service_id], automation_type: "confirmation_email_invitee")
        if email_invitee.count.zero?
          email_invitee_subject = t("mails.confirmation_email_invitee.subject").html_safe
          email_invitee_body = t("mails.confirmation_email_invitee.body").html_safe
          invitee_include_cancel_link = true
        else
          email_invitee_subject = email_invitee.first.subject
          email_invitee_body = email_invitee.first.text
          invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
        end

        email_host = client.service_notifications.where(service_id: params[:service_id], automation_type: "confirmation_email_host")
        if email_host.count.zero?
          use_email_host = false
          email_host_subject = t("mails.confirmation_email_host.subject").html_safe
          email_host_body = t("mails.confirmation_email_host.body").html_safe
        else
          email_host_subject = email_host.first.subject
          email_host_body = email_host.first.text
          use_email_host = email_host.first.use_email_host
        end

        event_date_time = Time.parse(params[:slot_start]).in_time_zone(@ivr.client.time_zone)
        event_date = I18n.localize(event_date_time.to_date, format: :long, locale: @ivr.voice_locale)
        event_time = event_date_time.strftime("%I:%M %p")
        event_day = event_date_time.strftime("%A")

        sms_invitee = client.service_notifications.where(service_id: params[:service_id], automation_type: "confirmation_sms_invitee")
        use_sms_invitee = true
        if sms_invitee.count.zero?
          sms_invitee_body = t("mails.confirmation_sms_invitee.body").html_safe
        else
          use_sms_invitee = sms_invitee.first.use_sms_invitee
          sms_invitee_body = sms_invitee.first.text
        end
        sms_invitee_body = sms_invitee_body % {event_name: service&.name, event_day: event_day, event_date: event_date, event_time: event_time,
                                   first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource&.name,
                                               choosen_slot_start: event_date, choosen_existing_appointment_time: event_date + ' at ' + event_time, caller_id: Customer.find(params[:customer_id]).full_name}

        sms_host = client.service_notifications.where(service_id: params[:service_id], automation_type: "confirmation_sms_host")

        if sms_host.count.zero?
          use_sms_host = false
          sms_host_body = t("mails.confirmation_sms_host.body").html_safe
        else
          use_sms_host = sms_host.first.use_sms_host
          sms_host_body = sms_host.first.text
        end
        sms_host_body = sms_host_body % {event_name: service&.name, event_day: event_day, event_date: event_date, event_time: event_time,
                                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource&.name,
                                         choosen_slot_start: event_date, choosen_existing_appointment_time: event_date + ' at ' + event_time, caller_id: Customer.find(params[:customer_id]).full_name}

        cancel_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: opts[:evt_id], type: 'cancel') : ''
        reschedule_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: opts[:evt_id], type: 'schedule') : ''
        if pre_confirmation
          accept_url = ENV['DOMAIN']+pre_confirmation_acceptance_path(opts[:evt_id], locale: nil)
          decline_url = ENV['DOMAIN']+pre_confirmation_cancelation_path(opts[:evt_id], locale: nil)
          ClientNotifierMailer.appointment_pre_confirmation_mail(@ivr.client.email, customer.email, formatted_time(st_time.in_time_zone(@ivr.client.time_zone),@ivr.voice_locale), caller_id,accept_url,decline_url, nil).deliver
          ClientNotifierMailer.appointment_pre_confirmation_mail_invitee(customer.email, formatted_time(st_time.in_time_zone(@ivr.client.time_zone),@ivr.voice_locale), caller_id, @ivr.client.email, email_invitee_subject, email_invitee_body).deliver
        else
          # ClientNotifierMailer.appointment_confirmation_mail(@ivr.client.email, formatted_time(st_time.in_time_zone(@ivr.client.time_zone),@ivr.voice_locale), caller_id, nil).deliver
          # ClientNotifierMailer.appointment_confirmation_mail(@ivr.client.email, (@ivr.client.first_name || '') + ' ' + (@ivr.client.last_name) + ' ' + service&.name, st_time.in_time_zone(@ivr.client.time_zone), caller_id, @ivr, cancel_link, reschedule_link, nil).deliver
          # ClientNotifierMailer.appointment_confirmation_mail_invitee(customer.email, customer.full_name + ' ' + service&.name, st_time.in_time_zone(@ivr.client.time_zone), caller_id,
          #                                                            resource&.name, @ivr, email_invitee_subject, email_invitee_body, cancel_link, reschedule_link).deliver

          if use_email_host
            email_body = email_host_body % {full_name: customer.full_name,
                                            first_name: customer.first_name,
                                            last_name: customer.last_name,
                                            resource_name: resource&.name,
                                            event_name: service&.name,
                                            event_date: l(event_date_time.to_date, format: :long, locale: @ivr.voice_locale),
                                            event_time: event_date_time.strftime("%I:%M %p"),
                                            event_day: event_date_time.strftime("%A")}

            template_data_client = {
              title: t("mails.client_appointment_confirmed.title"),
              body: email_body,
              subject: email_host_subject,
              copyright: t("mails.copyright"),
              reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
            }

            options = { to: @ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

            resource_user_email(resource, email_body, email_host_subject, "confirm")
          end

          email_body = email_invitee_body % {full_name: customer.full_name,
                                                 first_name: customer.first_name,
                                                 last_name: customer.last_name,
                                                 resource_name: resource&.name,
                                                 event_name: service&.name,
                                                 event_date: l(event_date_time.to_date, format: :long, locale: @ivr.voice_locale),
                                                 event_time: event_date_time.strftime("%I:%M %p"),
                                                 event_day: event_date_time.strftime("%A")}

          template_data_invitee = {
            title: t("mails.client_appointment_confirmed.title"),
            body: email_body,
            subject: email_invitee_subject,
            cancel_link: cancel_link,
            reschedule_link: reschedule_link,
            copyright: t("mails.copyright"),
            reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
          }

          options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: @ivr.client.email, reply_to_name: @ivr.client.full_name }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
        end

        send_sms_to_user(@ivr, customer.phone_number, sms_invitee_body.gsub(/<[^>]*>/,'')) if use_sms_invitee && is_valid_mobile(customer.phone_number)
        send_sms_to_user(@ivr, caller_id, sms_host_body.gsub(/<[^>]*>/,'')) if use_sms_host && is_valid_mobile(caller_id)
      rescue => exception1
        puts exception1
        # return render json: {message: 'send email/sms error' }, status: 422
      end
      return render json: {message: t("appointment_widget.book_success_title") }, status: 200
    rescue => exceptions
      return render json: {message: "create event error - #{exceptions.message}" }, status: 422
    end
  end

  def cancel_appointment
    event_id = params[:event_id]
    appointment = Appointment.where(event_id: event_id)
    event_date_time = appointment&.first&.time&.in_time_zone(@ivr.client.time_zone)

    event_params = {}
    from = event_date_time.utc
    to = from + 1.day
    event_params.merge!(include_managed: 1, from: from, to: to)

    appointments = []
    @ivr.client.agenda_apps.each do |agenda|
      # For ClassicAgenda
      if agenda.type == 'ClassicAgenda' && agenda.cronofy_access_token.present?
        appointments << agenda.get_events(agenda, from, to)
      end
      calendar_id = ''
      appointments[0].each do |appointment|
        calendar_id = appointment['calendar_id'] if appointment['event_id'] == event_id && calendar_id.blank?
      end
      agenda.delete_event(calendar_id,  event_id) if calendar_id.present?
    end

    if @ivr.client.agenda_apps.count.zero?
      @ivr.client.resources.where(ivr_id: @ivr.id).each do |resource|
        unless resource.application_access_token.blank?
          calendar_id = ''

          resource_cronofy = @ivr.client.create_cronofy(access_token: resource.application_access_token)
          appointments = resource_cronofy.read_events(event_params) rescue []
          appointments.each do |appointment|
            calendar_id = appointment['calendar_id'] if appointment['event_id'] == event_id && calendar_id.blank?
          end
          resource_cronofy.delete_event(calendar_id, event_id) if calendar_id.present?
        end
      end
    end

    event_name = appointment&.first&.service.name
    event_date = I18n.localize(event_date_time.to_date, format: :long, locale: @ivr.voice_locale)
    event_time = event_date_time.strftime("%I:%M %p")
    event_day = event_date_time.strftime("%A")
    customer = Customer.find(appointment&.first&.caller_id&.to_i)
    resource = Resource.find(appointment&.first&.resource_id)

    email_invitee_notification = ServiceNotification.where(service_id: appointment&.first&.service_id, automation_type: 'cancellation_email_invitee')
    email_invitee_subject = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.subject') : email_invitee_notification.first.subject
    email_invitee_body = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.body') : email_invitee_notification.first.text
    email_invitee_body = email_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
    email_invitee_body = email_invitee_body + "<br>" + t('appointment_widget.reason') + params[:reason]

    email_host_notification = ServiceNotification.where(service_id: appointment&.first&.service_id, automation_type: 'cancellation_email_host')
    email_host_subject = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.subject') : email_host_notification.first.subject
    email_host_body = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.body') : email_host_notification.first.text
    email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
    email_host_body = email_host_body + "<br>" + t('appointment_widget.reason') + params[:reason]
    use_email_host = email_host_notification.count.zero? ? false : email_host_notification.first.use_email_host

    sms_invitee_notification = ServiceNotification.where(service_id: appointment&.first&.service_id, automation_type: 'cancellation_sms_invitee')
    use_sms_invitee = true
    if sms_invitee_notification.count.zero?
      sms_invitee_body = I18n.t("mails.cancellation_sms_invitee.body")
    else
      use_sms_invitee = sms_invitee_notification.first.use_sms_invitee
      sms_invitee_body = sms_invitee_notification.first.text
    end
    sms_invitee_body = sms_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                           first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
    sms_invitee_body = sms_invitee_body + "<br>" + t('appointment_widget.reason') + params[:reason]

    sms_host_notification = ServiceNotification.where(service_id: appointment&.first&.service_id, automation_type: 'cancellation_sms_host')

    if sms_host_notification.count.zero?
      use_sms_host = false
      sms_host_body = I18n.t("mails.cancellation_sms_host.body")
    else
      use_sms_host = sms_host_notification.first.use_sms_host
      sms_host_body = sms_host_notification.first.text
    end
    sms_host_body = sms_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                     first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}

    # ClientNotifierMailer.generic_email(to: customer.email, subject: email_subject, body: email_body, reply_to_email: @ivr.client.email).deliver
    send_sms_to_user(@ivr, customer.phone_number, sms_invitee_body.gsub(/<[^>]*>/,'')) if use_sms_invitee && is_valid_mobile(customer.phone_number)
    send_sms_to_user(@ivr, @ivr.client.phone, sms_host_body.gsub(/<[^>]*>/,'')) if use_sms_host && is_valid_mobile(@ivr.client.phone)

    if use_email_host
      template_data_client = {
        title: t("mails.cancellation_email_invitee.title"),
        body: email_host_body,
        subject: email_host_subject,
        copyright: t("mails.copyright"),
        reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
      }
      options = { to: @ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_CANCEL'], template_data: template_data_client }
      SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

      if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
        team_client = Client.find(resource.team_calendar_client_id)
        if team_client
          team_client_email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
          team_client_email_host_body = team_client_email_host_body + "<br>" + t('appointment_widget.reason') + params[:reason]

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
    options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_CANCEL'], template_data: template_data_invitee, reply_to_email: @ivr.client.email, reply_to_name: @ivr.client.full_name }
    SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

    appointment = Appointment.find_by(event_id: event_id)
    if appointment
      appointment.answers.destroy_all
      # appointment.destroy
      appointment.update_columns(status: "Cancelled")
    end
    EventTrigger.where(event_id: event_id).destroy_all

    render json: {result: 'success', message: t("appointment_widget.cancel_success_title")}, status: 200
  end


  private

  def next_availability_mobile(start, service_id, resource_id)
    agenda = @ivr.client.agenda_apps.count.zero? ? DummyAgenda::new : @ivr.client.agenda_apps.first
    slots = agenda.free_slots(nil,start,{service_id: service_id, resource_id: resource_id, end_time: (DateTime.parse(start)+1.days).utc.iso8601, time_slot: params[:tslot]}) rescue nil
    new_start = next_available_slot(start, service_id, resource_id)
    slots.present? ? start : new_start["start"].strftime('%Y-%m-%d') rescue start
  end

  def resolve_layout
    case action_name
    when "index", "appointment"
      "widget"
    when "sms"
      "layout"
    else
      "application"
    end
  end

  def next_available_slot_for_schedule(start_time)
    return nil if @ivr.client.agenda_apps.count.zero?
    slots = []

    12.times do
      end_time = (DateTime.parse(start_time) + 30.days).utc.iso8601
      slots = @ivr.client.agenda_apps.first.free_slots_for_schedule(nil, start_time, end_time) rescue nil
      break if slots.present?

      start_time = end_time
    end

    slots&.first
  end

  def next_available_slot(start, service_id, resource_id)
    puts '---------------------------------------in next_available_slots'
    return nil if @ivr.client.agenda_apps.count.zero?

    slots = []

    12.times do
      end_time = (DateTime.parse(start)+30.days).utc.iso8601
      slots = @ivr.client.agenda_apps.first.free_slots(nil,start,{service_id: service_id, resource_id: resource_id, end_time: end_time, time_slot: nil}) rescue nil
      break if slots.present?

      start = end_time
    end

    puts '---slots here'
    puts slots&.first.inspect

    slots&.first
  end

  def times_in_day(slots, date)
    times = slots.map{|c| DateTime.parse(c["start"].to_s).strftime('%I:%M %p')  if Date.parse(c["start"].to_s) === date}
    times = times.reject! { |x| x.nil? }
  end

  def telephony_create(name, options={})
    case name
      when 'tropo'
        TropoEngine.new(options)
      when 'twilio'
        TwilioEngine.new(options)
      when 'voxi_sms'
        VoxiSMSEngin.new(options)
      else
        raise 'No'
    end
  end

  def telephony_name
    current_ivr.preference['sms_engin'] || 'twilio'
  end

  def is_valid_mobile(phone_no)
    phone = Phonelib.parse(phone_no)
    (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile)) rescue false
  end

  def create_sms(phone,text)
    sms_text = text

    opts = {
        to: phone,
        content: sms_text,
        sms_type: 'single_sms',
        ivr: current_ivr
    }
    TextMessage.create(opts)
  end

  def set_ivr
    @ivr = Ivr.where(id: params[:ivr_id])&.first
  end

  def slots_after_time start_time
    after_time = @ivr.nodes.find_by_name("agenda_group_availabilities").parameters["after_time"]
    case after_time.gsub(/[^A-Za-z]/, '')
      when 'minute'
        (Time.parse(start_time) + (60*after_time.gsub(/[^1-9]/, '').to_i)).strftime('%Y-%m-%d %H:%M:%S')
      when 'hour'
        (Time.parse(start_time) + (60*60*after_time.gsub(/[^1-9]/, '').to_i)).strftime('%Y-%m-%d %H:%M:%S')
      when 'day'
        Date.parse(start_time) + after_time.gsub(/[^1-9]/, '').to_i
      when 'week'
        Date.parse(start_time) + (after_time.gsub(/[^1-9]/, '').to_i * 7)
      when 'month'
        Date.parse(start_time) >> after_time.gsub(/[^1-9]/, '').to_i
      else
        Date.parse(start_time)
    end
  end

  def max_allowed_appointments(customer_id, resource_id)
    opts = {calendar_ids: Resource.find(resource_id)&.calendar_id&.split(' '), agenda_customer_id: customer_id}
    agenda = @ivr.client.agenda_apps.count.zero? ? DummyAgenda::new : @ivr.client.agenda_apps.first
    appointments = agenda.existing_appointments(opts) || []
    count = appointments.count

    limit_reached = false
    limit_reached = false if !@ivr.preference["max_allowed_appointments"].nil? && @ivr.preference["max_allowed_appointments"] > 0
    limit_reached = true  if !@ivr.preference["max_allowed_appointments"].nil? && count >= @ivr.preference["max_allowed_appointments"]

    limit_reached
  end

  def send_sms_to_user(ivr, to, message)
    telephony_name = ivr.preference['sms_engin'] || 'twilio'
    telephony = TropoEngine.new({}) if telephony_name == 'tropo'
    telephony = TwilioEngine.new({}) if telephony_name == 'twilio'
    telephony = VoxiSMSEngin.new({}) if telephony_name == 'voxi_sms'

    sms = TextMessage.create({to: to, content: message, sms_type: 'single_sms', ivr: ivr})
    telephony.send_sms(sms.id)
  end

  def formatted_time(time,voice_locale)
    format = if I18n.exists?('time.formats.custom', voice_locale)
               :custom
             else
               :long
             end

    l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def customer_params
    params.permit(:first_name ,:last_name, :phone_number,:email ,:gender ,:birthday ,:city ,:street ,:zipcode ,:notes, contacts_attributes: [:phone, :country])
  end

  def send_notification_email
    ClientNotifierMailer.generic_email(
      to: ENV['ERROR_MAIL_RECIPIENTS'],
      subject: 'Fake booking appointment.',
      body: params.to_yaml
    ).deliver

    # redirect_to root_path, error: 'Please contact our support.'
  end
end
