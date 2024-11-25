class DummyAgenda < AgendaApp
  include LocalResourceAndServices
  # required
  # service_id
  # date
  #
  AVAILABLE_PERIODS_TIME_PARAMS = %i{
    start
    end
  }.freeze

  def ServiceAvailabilities(service)
    if service.schedule_template_id.positive?
      schedule_template = ScheduleTemplate.find(service.schedule_template_id)
      schedule_template.availability.availabilities

      {
        "availability" => schedule_template.availability.availabilities,
        "overrides" => schedule_template.availability.overrides
      }
    else
      {
        "availability" => service.availability,
        "overrides" => service.overrides
      }
    end
  end

  def ResourceAvailabilities(resource)
    if resource.schedule_template_id.positive?
      schedule_template = ScheduleTemplate.find(resource.schedule_template_id)
      schedule_template.availability.availabilities

      {
        "availability" => schedule_template.availability.availabilities,
        "overrides" => schedule_template.availability.overrides
      }
    else
      {
        "availability" => resource.availability,
        "overrides" => resource.overrides
      }
    end
  end

  def periods_overrides(overrides)
    override_availability = []
    override_unavailability = []
    override_hours = overrides&.keys || []
    override_hours.each do |oday|
      override = overrides[oday]
      override.each do |override_hour|
        if override_hour['from'] && override_hour['to']
          from_hour = oday + " " + override_hour['from'] || override_hour[:from]
          to_hour = oday + " " + override_hour['to'] || override_hour[:to]

          if Time.current.utc < Time.zone.parse(to_hour).utc
            override_availability.push(
              :start => Time.zone.parse(from_hour).utc > Time.current.utc ? Time.zone.parse(from_hour).utc : Time.current.utc,
              :end => Time.zone.parse(to_hour).utc
            )
          end
        else
          from_hour = oday + " 00:00"
          to_hour = oday + " 23:59"

          if Time.current.utc < Time.zone.parse(to_hour).utc
            override_unavailability.push(
              :start => Time.zone.parse(from_hour).utc > Time.current.utc ? Time.zone.parse(from_hour).utc : Time.current.utc,
              :end => Time.zone.parse(to_hour).utc
            )
          end
        end
      end
    end

    {
      override_availability: override_availability,
      override_unavailability: override_unavailability
    }
  end

  def calculate_availabilities(type, obj, after_time, before_time)
    availabilities = type =="service" ? ServiceAvailabilities(obj) : ResourceAvailabilities(obj)
    availability = periods(start_time: after_time, end_time: before_time, schedule: availabilities["availability"])
    overrides = periods_overrides(availabilities["overrides"])
    availability = availability.concat(overrides[:override_availability]) if overrides[:override_availability].count.positive?
    overrided_availability = []

    if overrides[:override_unavailability].count.positive?
      overrides[:override_unavailability].each do |override_unavailability|
        availability.each do |availability_item|
          if availability_item[:start] > override_unavailability[:start] && availability_item[:start] < override_unavailability[:end] || availability_item[:end] > override_unavailability[:start] && availability_item[:end] < override_unavailability[:end]
            if availability_item[:start] > override_unavailability[:start] && availability_item[:start] < override_unavailability[:end]
              if availability_item[:end] > override_unavailability[:end]
                availability_item[:start] = override_unavailability[:end]
                overrided_availability.push(availability_item)
              end
            end
            if availability_item[:end] > override_unavailability[:start] && availability_item[:end] < override_unavailability[:end]
              if availability_item[:start] < override_unavailability[:start]
                availability_item[:end] = override_unavailability[:start]
                overrided_availability.push(availability_item)
              end
            end
          else
            overrided_availability.push(availability_item)
          end
        end
      end
    else
      overrided_availability = availability
    end
    overrided_availability
  end

  def free_slots(number_of_slots, after_time=Time.current, options = {})
    options.symbolize_keys!
    service = Service.find options[:service_id]
    resource = Resource.find options[:resource_id]
    before_time = options[:end_time] ? options[:end_time] : nil

    members = []
    required = "1"

    application_calendar = ApplicationCalendar.find_by_calendar_id(resource.calendar_id)

    if service.resource_distribution == "random" || service.resource_distribution == "collective" || service.random_resource_widget
      service.resources.each do |resource|
        member = {
          "sub" => application_calendar.application_sub,
          "calendar_ids" => resource.conflict_calendars.split(","),
          "available_periods" => calculate_availabilities('resource', resource, after_time, before_time)
        }

        members.push(member)
      end

      required = "all" if service.resource_distribution == "collective"
    else
      if service.resource_distribution == "one"
        resource = service.resources[0]
      end

      member = {
        "sub" => application_calendar.application_sub,
        "calendar_ids" => resource.conflict_calendars.split(","),
        "available_periods" => calculate_availabilities('resource', resource, after_time, before_time)
      }

      members.push(member)
    end

    availabilities = {
      participants: [
        {
          members: members,
          required: required
        }
      ],
      required_duration: { minutes: service.duration + service.buffer || BusinessHours::DEFAULT_DURATION },
      query_periods: calculate_availabilities('service', service, after_time, before_time),
      start_interval: { minutes: service.start_interval.nil? ? BusinessHours::DEFAULT_DURATION : service.start_interval.to_i },
      response_format: service.response_format ? service.response_format : 'slots',
      buffer: {
        before: { minutes: service.buffer_before },
        after: { minutes: service.buffer_after }
      },
      max_results: 512
    }

    periods = formatted_slots(availabilities, resource.client.data_server)
    @slots = periods.select{|p| p['start'].to_time > after_time}.map do |r|
      {
        'start' => r['start'].in_time_zone,
        'finish' => r['end'].in_time_zone,
        'resource_id' => resource.id
      }
    end

    if options[:full_day]
      # considering slots are in alphabatically order
      @next_group = @slots.find{|x| x['start'].to_date > after_time.to_date }
      @next_group = @next_group['start'].to_date if @next_group
      @slots.select!{|x| x['start'].to_date == after_time.to_date }
    end

    @slots
  rescue => e
    puts e
    raise NoAvalibilityError
  end

  def to_iso8601(value)
    case value
    when NilClass, String
      value
    when Time
      value.getutc.iso8601
    else
      value.iso8601
    end
  end

  def formatted_slots(availability_values, data_center)
    availability_values[:participants][0][:members].each do |member|
      member["available_periods"].each do |params|
        AVAILABLE_PERIODS_TIME_PARAMS.select { |tp| params.key?(tp) }.each do |tp|
          params[tp] = to_iso8601(params[tp])
        end
      end
    end

    availability_values[:query_periods].each do |params|
      AVAILABLE_PERIODS_TIME_PARAMS.select { |tp| params.key?(tp) }.each do |tp|
        params[tp] = to_iso8601(params[tp])
      end
    end

    response = HTTParty.post(ApplicationController.helpers.get_api_center_url(data_center.downcase) + '/v1/availability', { headers: { 'Authorization' => 'Bearer ' + ENV["CRONOFY_#{data_center}_CLIENT_SECRET"] }, body: availability_values })

    response['available_slots']
  end

  def make_slots(time, end_time, duration)
    time = time.to_time
    end_time = end_time.to_time
    duration ||= BusinessHours::DEFAULT_DURATION

    slots = []
    while time <= end_time - duration.minutes
      slots << {
        start: time,
        end: time + duration.minutes
      }
      time += duration.minutes
    end
    slots
  end

  def periods(start_time: , end_time: nil, schedule: nil)
    start_time = Time.parse(start_time) if start_time.class === 'String'
    start_time = Time.current if start_time < Time.current.utc
    end_time = Time.parse(end_time) if end_time.class === 'String'
    end_time ||= start_time + 30.days
    end_time = start_time + 3.days if end_time <= start_time

    available_periods = []
    # schedule = {"mon"=>[{"from"=>"09:00", "to"=>"12:00"}, {"from"=>"13:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"12:00"}, {"from"=>"13:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}

    ((start_time.to_date)..(end_time.to_date)).each_with_index do |date, i|
      weekday = date.strftime("%a").downcase
      if schedule.include? weekday
        periods = schedule[weekday]
      else
        periods = schedule[weekday.to_sym]
      end
      next unless periods
      # max limit is 50 by cronofy
      break if available_periods.size > 40
      periods.each do |p|
        if p.include? 'from'
          from = Time.zone.parse("#{date}T#{p['from']}")
          to = Time.zone.parse("#{date}T#{p['to']}")
        else
          from = Time.zone.parse("#{date}T#{p[:from]}")
          to = Time.zone.parse("#{date}T#{p[:to]}")
        end

        from = start_time if from < start_time
        # to = end_time if to > end_time && to > Time.current

        if i == 0
          next if from < Time.current - 1.second # skip this period
        end

        if i == 0
          next if to < from # skip this period
        end

        available_periods << {
          start: from.utc,
          end: to.utc < from.utc ? from.utc : to.utc
        }
      end

    end

    available_periods
  end

  # required params
  # -> resource_id
  # -> datetime
  # -> duration
  # -> title or service_id
  def create_appointment(params = {})
    params.symbolize_keys!
    resource = Resource.find_by(id: params[:resource] || params[:resource_id])
    service = Service.find_by(id: params[:service])
    # call = Call.find_by(id: params[:call_id]) if params[:call_id].present?

    # call_type = call.client_type ? call.client_type == 'new' ? t('call_stats.new') : call.client_type.try(:camelize) : ' ' if call.present?

    customer = Customer.find(params[:customer_id])

    attributes = {
      first_name: customer.first_name || ' ',
      last_name: customer.last_name || ' ',
      # type: call_type || ' ',
      phone_number: customer.phone_number || ' ',
      email: customer.email || ' ',
      service_name: service.name || ' ',
      resource_name: resource.name || ' '
    }.compact

    if params[:questions]
      params[:questions].each do |q|
        attributes.merge!("#{q['question']}": q['answer'])
      end
    end

    description = ""
    attributes.each{|k,v| description += "#{k.to_s.humanize}: #{v} \n"}

    event_summary = I18n.t('classic_agenda.event_summary', people_name: customer.full_name,service: service.name)
    event_data = {
      event_id: params[:evt_id].presence || SecureRandom.hex,
      tzid: Time.zone.tzinfo.identifier,
      # summary: "Appointment for #{client_info}",
      summary: event_summary,
      description: description,
      start: params[:start],
      end: params[:end],
      # location: {
      #     description: "Meeting room"
      # }
    }

    # upsert_event returns nothing on success and will raise an exception on failure
    access_token = ApplicationCalendar.find_by_calendar_id(resource.calendar_id).access_token
    refresh_token = ApplicationCalendar.find_by_calendar_id(resource.calendar_id).refresh_token
    cronofy = resource.client.create_cronofy(access_token: access_token, refresh_token: refresh_token)
    cronofy.upsert_event(resource.calendar_id, event_data)
    params[:evt_id].replace(event_data[:event_id]) if params[:evt_id]
    puts '-=-=-=-=-=-=-=-session was set-=-=-=-=-=-=-=--='
    puts params[:evt_id]

    ApplicationController.helpers.create_event_trigger(service, resource,
                                                       {'id': event_data[:event_id], 'summary': event_summary, 'start': params[:start].utc.iso8601, 'end': params[:end].utc.iso8601},
                                                       access_token, resource.calendar_id)

    {result: true, event: event_data}
  rescue => e
    puts e
  end

  # required params
  # -> resource_id
  # -> datetime
  # -> duration
  # -> title or service_id
  def update_appointment(params = {})
   true
  end

  def delete_appointment(event_id)
    exist_appointments = Appointment.where(event_id: event_id)
    return true if exist_appointments.count.zero?
    resource_id = exist_appointments.first.resource_id
    resource = Resource.find(resource_id)
    application_calendar_id = resource&.application_calendar_id
    application_access_token = resource&.application_access_token
    application_refresh_token = resource&.application_refresh_token
    cronofy = resource.client.create_cronofy(access_token: application_access_token, refresh_token: application_refresh_token)
    cronofy.delete_event(application_calendar_id, event_id)
    EventTrigger.where(event_id: event_id).destroy_all
    {result: true, event: 'delete_event'}
  rescue
    {result: false, event: 'delete_event'}
  end

  def is_connected?
    true
  end

  def existing_appointments(params = {})
    reg = /\d+/
    begin
      customer = Customer.find(params[:agenda_customer_id])
      phones = customer.contacts.pluck(:phone).map { |a| a.gsub('+','')} if customer.contacts
    rescue => e
      puts e
      phones = []
    end
    params.merge!(include_managed: 1, from: Time.current)

    resources_application_access_tokens = customer.client.resources.map { |a| ApplicationCalendar.find_by_calendar_id(a.calendar_id).access_token }
    resources_application_refresh_tokens = customer.client.resources.map { |a| ApplicationCalendar.find_by_calendar_id(a.calendar_id).refresh_token }
    events = []
    access_tokens = []

    calendar_ids = customer.client.resources.map { |a| a.calendar_id }
    params.merge!(calendar_ids: calendar_ids)

    resources_application_access_tokens.each_with_index do |application_access_token, index|
      existed = false

      access_tokens.each do |access_token|
        if access_token == application_access_token
          existed = true
          break
        end
      end

      unless existed
        access_tokens.push(application_access_token)
        cronofy = customer.client.create_cronofy(access_token: application_access_token, refresh_token: resources_application_refresh_tokens[index])
        events << cronofy.read_events(params) rescue []
      end
    end

    appointments = []

    events.each do |event|
      event.each do |appointment|
        (appointment.summary.to_s+' '+appointment.description.to_s).scan(reg).uniq.each do |phone|
          appointments << appointment if phones.include? phone.gsub('+','')
        end
      end
    end

    appointments = appointments.uniq.map do |a|
      {
        'id' => a['event_id'],
        'time' => DateTime.parse(a['start'].time.to_s).in_time_zone(customer.client.time_zone),
        'resource' => Appointment.where(event_id: a['event_id'])&.first&.resource_id || customer&.client&.default_resource&.id,
        'service' => Appointment.where(event_id: a['event_id'])&.first&.service_id || customer&.client&.default_service&.id
      }
    end
    appointments.delete_if {|x| x['time'] < Time.current } if appointments
  end

  def existing_appointments_reminders(params = {})
    []
  end

  def required_attrs(slot)
    attrs = slot.slice('resource_id', 'service_id')
    attrs['start'] = slot['start']
    attrs['end'] = slot['finish']
    attrs
  end

  def common_required_attrs(attributes)
    {
      customer_id: attributes[:agenda_customer_id],
      service: attributes[:service],
      resource: attributes[:resource],
      id: attributes[:existing_appointment_id],
      start: attributes[:start],
      end: attributes[:finish]
    }
  end

  def next_group_after_time(slots)
    # for tropo we need to send a date instead of datetime
    slots.max {|g| g['start']}['finish'] + 1.day
  end

  def find_customer(phone: , client_id: nil)
    current_client = Client.find_by_id(client_id)
    contact = current_client.contacts.find_by phone: parse_phone(phone).e164
    return contact.customer if contact
    current_client.customers.find_by(phone_number: sanitize(phone))
  end

  # save agenda customer in local db
  def create_local_customer(customer)
    customer
  end

  # we can perform this in background to improve performance
  def create_customer_on_agenda(local_customer_id)
    customer = Customer.find(local_customer_id)
    customer.update(eid: local_customer_id) # eid is used on some places
  end

end