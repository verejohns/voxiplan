class ClassicAgenda < AgendaApp
  include LocalResourceAndServices

  attr_accessor :default_resource_calendar

  delegate :default_resource, to: :client

  after_save :set_default_resource_calendar

  AVAILABLE_PERIODS_TIME_PARAMS = %i{
    start
    end
  }.freeze

  def default_resource_calendar
    @default_resource_calendar = default_resource.calendar_id if default_resource
  end

  def default_resource_calendar=(val)
    @default_resource_calendar = val
  end


  # auth example
  # --- !ruby/hash:OmniAuth::AuthHash
  # provider: cronofy
  # uid: acc_5692658db4ccd0137100868a
  # info: !ruby/hash:OmniAuth::AuthHash::InfoHash
  #   email: buy@voxiness.com
  #   name: Axel Boven
  # credentials: !ruby/hash:OmniAuth::AuthHash
  #   token: SSIMjZDntMAhzo3989sswV09QDS3xyu6
  #   refresh_token: 4X6utVMV21sual8SmEM2JgCUVDOHN4CJ
  #   expires_at: 1556192403
  #   expires: true
  # extra: !ruby/hash:OmniAuth::AuthHash
  #   raw_info: !ruby/hash:OmniAuth::AuthHash
  #     account_id: acc_5692658db4ccd0137100868a
  #     email: buy@voxiness.com
  #     name: Axel Boven
  #     type: account
  #     scope: create_event list_calendars read_account delete_event read_free_busy create_calendar
  #       read_events
  #     default_tzid: Europe/Brussels
  #   linking_profile: !ruby/hash:OmniAuth::AuthHash
  #     provider_name: google
  #     profile_id: pro_XINva9B2PhfuWCFH
  #     profile_name: work.teknuk@gmail.com
  def self.create_with_omniauth(params, auth)
    agenda = AgendaApp.find_by(id: params['agenda_app'])
    return false unless agenda
    profile = auth.extra.linking_profile
    agenda.update_attributes(
        cronofy_access_token: auth.credentials.token,
        cronofy_refresh_token: auth.credentials.refresh_token,
        cronofy_profile_id: profile.profile_id,
        cronofy_profile_name: profile.profile_name,
        cronofy_provider_name: profile.provider_name,
        cronofy_account_id: auth.uid,
    )
  end

  def all_calendars
    return [] unless cronofy_access_token
    return @calendars unless @calendars.nil?
    return [] unless cronofy
    calendars = cronofy.list_calendars
    @calendars = calendars.select{|c| c.profile_id == self.cronofy_profile_id}.map{|c| [c.calendar_name, c.calendar_id]}
  rescue Exception => e
    puts "********************************* all_calendars error ****************************************"
    puts e
    puts e.message
    return []
  end

  def find_customer(phone: , client_id: nil)
    client = Client.find(client_id) unless client_id.nil?
    contact = client.contacts.find_by phone: parse_phone(phone).e164
    return contact.customer if contact
    client.customers.find_by(phone_number: sanitize(phone))
  end

  def create_local_customer(customer)
    customer
  end

  def create_customer_on_agenda(local_customer_id)
    customer = Customer.find(local_customer_id)
    customer.update(eid: local_customer_id) # eid is used on some places
  end

  def tst
    cronofy = AgendaApp.find(2).send(:cronofy)
    r = cronofy.availability(availability(Time.current + 1.day, resource: Resource.find(22),service: Service.find(11)))
    puts r.to_yaml
    r.map { |p| make_slots(p[:start], p[:end], 30) }.flatten
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
    puts "*************** periods **************"
    puts start_time
    start_time = Time.parse(start_time) if start_time.class === 'String'
    start_time = Time.current if start_time < Time.current.utc
    end_time = Time.parse(end_time) if end_time.class === 'String'
    end_time ||= start_time + 30.days
    end_time = start_time + 3.days if end_time <= start_time
    puts schedule
    available_periods = []
    # schedule = {"mon"=>[{"from"=>"09:00", "to"=>"12:00"}, {"from"=>"13:00", "to"=>"17:00"}], "tue"=>[{"from"=>"09:00", "to"=>"12:00"}, {"from"=>"13:00", "to"=>"17:00"}], "wed"=>[{"from"=>"09:00", "to"=>"17:00"}], "thu"=>[{"from"=>"09:00", "to"=>"17:00"}], "fri"=>[{"from"=>"09:00", "to"=>"17:00"}]}

    ((start_time.to_date)..(end_time.to_date)).each_with_index do |date, i|
      puts date
      weekday = date.strftime("%a").downcase
      puts weekday
      if schedule.include? weekday
        periods = schedule[weekday]
      else
        periods = schedule[weekday.to_sym]
      end
      puts periods
      next unless periods
      # max limit is 50 by cronofy
      break if available_periods.size > 40
      periods.each do |p|
        puts p
        if p.include? 'from'
          from = Time.zone.parse("#{date}T#{p['from']}")
          to = Time.zone.parse("#{date}T#{p['to']}")
        else
          from = Time.zone.parse("#{date}T#{p[:from]}")
          to = Time.zone.parse("#{date}T#{p[:to]}")
        end

        from = start_time if from < start_time
        # to = end_time if to > end_time && to > Time.current
        puts from
        puts to
        puts Time.current
        puts "************* Time.current ***************"
        if i == 0
          next if from < Time.current - 1.second # skip this period
        end

        if i == 0
          next if to < from # skip this period
        end
        puts from
        puts to
        available_periods << {
            start: from.utc,
            end: to.utc < from.utc ? from.utc : to.utc
        }
      end

    end

    available_periods
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
    availability_values[:participants].each do |participant|
      participant[:members].each do |member|
        member["available_periods"].each do |params|
          AVAILABLE_PERIODS_TIME_PARAMS.select { |tp| params.key?(tp) }.each do |tp|
            params[tp] = to_iso8601(params[tp])
          end
        end
      end
    end

    availability_values[:query_periods].each do |params|
      AVAILABLE_PERIODS_TIME_PARAMS.select { |tp| params.key?(tp) }.each do |tp|
        params[tp] = to_iso8601(params[tp])
      end
    end

    response = HTTParty.post(ApplicationController.helpers.get_api_center_url(data_center.downcase) + '/v1/availability', { headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer ' + ENV["CRONOFY_#{data_center}_CLIENT_SECRET"] }, body: availability_values.to_json })

    response['available_slots']
  end

  def availability_for_agenda(start_time, end_time)
    members = []
    query = "SELECT cronofy_account_id, STRING_AGG(conflict_calendars, ',') conflict_calendars FROM agenda_apps WHERE ivr_id=#{ivr.id} GROUP BY cronofy_account_id"
    agenda_apps = ActiveRecord::Base.connection.exec_query(query)
    agenda_apps.each do |agenda|
      unless agenda["conflict_calendars"].blank?
        conflict_calendars = agenda["conflict_calendars"].split(",")
        member = { "sub" => agenda["cronofy_account_id"], "calendar_ids"=> conflict_calendars }
        members.push(member)
      end
    end

    if members.count.zero?
      ivr.resources.where("application_calendar_id IS NOT NULL").each do |resource|
        member = { "sub" => resource.application_sub, "calendar_ids"=> [resource.application_calendar_id] }
        members.push(member)
      end
    end
    period = periods(start_time: start_time, end_time: end_time, schedule: BusinessHours::DEFAULT_AVAILABILITY)

    {
      participants: [ { members: members, required: '1' }],
      required_duration: { minutes: BusinessHours::DEFAULT_DURATION },
      query_periods: period,
      start_interval: { minutes: BusinessHours::DEFAULT_DURATION },
    }
  end

  def availability_for_resource(start_time, end_time)
    members = []
    ivr.resources.where("application_calendar_id IS NOT NULL").each do |resource|
      member = { "sub" => resource.application_sub, "calendar_ids"=> [resource.application_calendar_id] }
      members.push(member)
    end

    {
      participants: [ { members: members, required: '1' }],
      required_duration: { minutes: BusinessHours::DEFAULT_DURATION },
      query_periods: periods(start_time: start_time, end_time: end_time, schedule: BusinessHours::DEFAULT_AVAILABILITY),
      start_interval: { minutes: BusinessHours::DEFAULT_DURATION },
    }
  end

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
    puts "********** calculate_availabilities - after_time: #{after_time} ******************"
    puts "********** calculate_availabilities - before_time: #{before_time} ******************"
    puts "********** calculate_availabilities - schedule: #{availabilities["availability"]} ******************"

    availability = periods(start_time: after_time, end_time: before_time, schedule: availabilities["availability"])
    puts "************* calculate_availabilities - availability: #{availability} ******************"
    overrides = periods_overrides(availabilities["overrides"])
    puts "************* calculate_availabilities - overrides: #{overrides} ******************"

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

  def availability(after_time, before_time: nil, resource: nil, service: nil)
    resources = [resource].compact
    resources ||= service.resources if service
    return unless resources.present?
    # calendar_ids = resources.map{|r| r.calendar_id.presence || client.default_resource.calendar_id }.compact.uniq
    # ps = periods(start_time: after_time, schedule: resource.use_default_availability? ? default_resource_availability : resource.availability)

    participants = []

    if service.resource_distribution == "random" || service.resource_distribution == "collective" || service.random_resource_widget
      application_subs = []

      service.resources.each do |resource|
        unless resource.conflict_calendars.nil?
          resource.conflict_calendars.split(",").each do |conflict_calendar|
          if AgendaApp.where('conflict_calendars like ? ', "%#{conflict_calendar}%").first
            calendar = AgendaApp.where('conflict_calendars like ? ', "%#{conflict_calendar}%").first
            application_sub = {
              sub: calendar.cronofy_account_id,
              id: calendar.conflict_calendars
            }
          elsif ApplicationCalendar.where(conflict_calendars: conflict_calendar).first
            calendar = ApplicationCalendar.where(conflict_calendars: conflict_calendar).first
            application_sub = {
              sub: calendar.application_sub,
              id: calendar.conflict_calendars
            }
          end

          same_sub_flag = false
          application_subs.each do |item|
            if item[:sub] == application_sub[:sub]
              same_sub_flag = true
              item[:id].concat(application_sub[:id])
              break
            end
          end

          application_subs.push(application_sub) unless same_sub_flag
        end
        end
      end

      application_subs.each do |application_sub|
        all_periods = []

        service.resources.each do |resource|
          all_periods = all_periods + calculate_availabilities('resource', resource, after_time, before_time)
        end

        cal_periods = []
        all_periods.each do |period|
          required_num = 0
          all_periods.each do |all_period|
            required_num = required_num + 1 if all_period == period
          end

          cal_periods.push({ period: period, required_num: required_num }) unless cal_periods.include?({ period: period, required_num: required_num })
        end

        real_periods = []
        cal_periods.each do |cal_period|
          real_periods.push(cal_period[:period]) if service.resource_distribution == "collective" && cal_period[:required_num] == service.resources.count || service.resource_distribution != "collective" && cal_period[:required_num] > 0
        end

        member = {
          "sub" => application_sub[:sub],
          "calendar_ids" => [application_sub[:id]],
          "available_periods" => real_periods
        }

        participant = {
          members: [member],
          "required": service.resource_distribution == "collective" ? "all" : "1"
        }

        participants.push(participant)
      end
    else
      if service.resource_distribution == "one"
        resource = service.resources[0]
      end

      unless resource.conflict_calendars.nil?
        resource.conflict_calendars.split(",").each do |conflict_calendar|
        application_sub = ''

        if AgendaApp.where('conflict_calendars like ? ', "%#{conflict_calendar}%").first
          calendar = AgendaApp.where('conflict_calendars like ? ', "%#{conflict_calendar}%").first
          application_sub = calendar.cronofy_account_id
        elsif ApplicationCalendar.where(conflict_calendars: conflict_calendar).first
          calendar = ApplicationCalendar.where(conflict_calendars: conflict_calendar).first
          application_sub = calendar.application_sub
        end

        same_sub_flag = false
        participants.each do |participant|
          if participant[:members][0]["sub"] == application_sub
            same_sub_flag = true
            participant[:members][0]["calendar_ids"].push(conflict_calendar)
            break
          end
        end

        puts "******* after time: #{after_time} *************"
        unless same_sub_flag
          member = {
            "sub" => application_sub,
            "calendar_ids" => [conflict_calendar],
            "available_periods" => calculate_availabilities('resource', resource, after_time, before_time)
          }

          members = [member]
          participant = {
            members: members,
            "required": "1"
          }

          participants.push(participant)
        end
      end
      end
    end

    {
        participants: participants,
        required_duration: { minutes: service.duration + service.buffer || BusinessHours::DEFAULT_DURATION },
        query_periods: calculate_availabilities('service', service, after_time, before_time),
        start_interval: { minutes: ivr.preference['start_interval'].nil? ? BusinessHours::DEFAULT_DURATION : ivr.preference['start_interval'].to_i },
        response_format: service.response_format ? service.response_format : 'slots',
        buffer: {
          before: { minutes: service.buffer_before },
          after: { minutes: service.buffer_after }
        },
        max_results: 512
    }
  end

  def free_slots_for_schedule(number_of_slots, start_time, end_time, slot_type)
    begin
      calendars = slot_type == 'agenda' ? availability_for_agenda(start_time, end_time) : availability_for_resource(start_time, end_time)
      periods = []
      if self.cronofy_access_token.nil?
        ivr.client.resources.where(ivr_id: ivr.id).each do |resource|
          unless resource.application_access_token.blank?
            resource_cronofy = ivr.client.create_cronofy(access_token: resource.application_access_token, refresh_token: resource.application_refresh_token)
            periods = periods + resource_cronofy.availability(calendars)
          end
        end

      else
        periods = cronofy.availability(calendars)
      end

      cronofy_slots = periods.map { |p| make_slots(p[:start], p[:end], BusinessHours::DEFAULT_DURATION) }.flatten
      @slots = cronofy_slots.select{|p| p[:start].to_time > start_time}.map do |r|
        {
          'start' => r[:start].in_time_zone,
          'finish' => r[:end].in_time_zone,
          'resource_id' => nil
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

  end

  def free_slots(number_of_slots, after_time=Time.current, options = {})
    puts "*************** free_slots ****************"
    puts after_time
    puts options
    options.symbolize_keys!
    service = Service.find options[:service_id]
    resource = Resource.find options[:resource_id]
    before_time = options[:end_time] ? options[:end_time] : nil
    # params = {service_id: service_id, date: after_time.to_date, resource_id: resource_id}.compact

    begin
      calendars = availability(after_time, before_time: before_time, resource: resource, service: service)
      puts "************* calendars **************"
      puts calendars
      periods = formatted_slots(calendars, resource.client.data_server)
      puts "*************** periods **************"
      puts periods
      if periods.nil?
        @slots = {}
      else
        @slots = periods.select{|p| p['start'].to_time > after_time}.map do |r|
          {
            # 'service_id' => service_id,
            # 'resource_id' => resource_id,
            'start' => r['start'].in_time_zone,
            'finish' => r['end'].in_time_zone,
            'resource_id' => resource.id
          }
        end
      end
    rescue => e
      puts e
      raise NoAvalibilityError
    end

    # wrong after time is set
    if options[:full_day]
      # considering slots are in alphabatically order
      @next_group = @slots.find{|x| x['start'].to_date > after_time.to_date }
      @next_group = @next_group['start'].to_date if @next_group
      @slots.select!{|x| x['start'].to_date == after_time.to_date }
    end

    @slots
    # @slots.select!{|s| s['start'] > after_time}
    # @slots = @slots.group_by {|s| s['start']}.map {|k, v| v[0]} unless resource_id.present?
    super
  end

  def required_attrs(slot)
    attrs = slot.slice('resource_id', 'service_id')
    # attrs = slot.slice('resource_id', 'service_id')
    # attrs = {}
    attrs['start'] = slot['start']
    attrs['end'] = slot['finish']
    # attrs['end'] = ((slot['finish'] - slot['start']) * 24 * 60).to_i
    attrs
  end

  def common_required_attrs(attributes)
    {
        customer_id: attributes[:customer_id],
        service: attributes[:service],
        resource: attributes[:resource]
    }
  end

  def create_appointment(params = {})
    params.symbolize_keys!
    resource = Resource.find_by(id: params[:resource])
    service = Service.find_by(id: params[:service])
    # call = Call.find_by(id: params[:call_id]) if params[:call_id].present?

    # call_type = call.client_type ? call.client_type == 'new' ? t('call_stats.new') : call.client_type.try(:camelize) : ' ' if call.present?

    customer = Customer.find(params[:customer_id])
    client_info = [customer.first_name, customer.last_name, customer.phone_number].compact.join(' ')

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
    if service.preference["add_invitee"] == 'true'
      unless service.preference["pre_confirmation"] == 'true'
        event_data.merge!(
          attendees: {
              invite: [
                # {
                #   email: client.email,
                #   display_name: client.first_name
                # },
                {
                  email: customer.email.presence || "#{(customer.phone_number.presence || customer.contacts.first.phone).gsub('+','')}@voxi.ai",
                  display_name: customer.first_name.presence || 'X'
                }
              ],
              remove: []
            }
        )
      end
    end

    access_token = AgendaApp.where(calendar_id: resource.calendar_id).count > 0 ?
                     AgendaApp.where(calendar_id: resource.calendar_id).first.cronofy_access_token :
                     ApplicationCalendar.find_by_calendar_id(resource.calendar_id).access_token
    refresh_token = AgendaApp.where(calendar_id: resource.calendar_id).count > 0 ?
                     AgendaApp.where(calendar_id: resource.calendar_id).first.cronofy_refresh_token :
                     ApplicationCalendar.find_by_calendar_id(resource.calendar_id).refresh_token
    if resource.calendar_id.nil?
      cronofy = resource.client.create_cronofy(server_region: nil, access_token: access_token, refresh_token: refresh_token)
      calendar_id = resource.application_calendar_id
      cronofy.upsert_event(calendar_id, event_data)
    else
      cronofy = resource.client.create_cronofy(server_region: nil, access_token: access_token, refresh_token: resource.application_refresh_token)
      calendar_id = resource.calendar_id.presence || client.default_resource.calendar_id
      cronofy.upsert_event(calendar_id, event_data)
    end
    params[:evt_id].replace(event_data[:event_id]) if params[:evt_id]
    puts '-=-=-=-=-=-=-=-session was set-=-=-=-=-=-=-=--='
    puts params[:evt_id]

    ApplicationController.helpers.create_event_trigger(service, resource,
                                                       {'id': event_data[:event_id], 'summary': event_summary, 'start': params[:start].utc.iso8601, 'end': params[:end].utc.iso8601},
                                                       access_token, calendar_id)

    {result: true, event: event_data}
  rescue => e
    puts e
  end

  def create_event(event_data)
    ivr = Ivr.find(self.ivr_id)
    cronofy = ivr.client.create_cronofy(access_token:  self.cronofy_access_token, refresh_token: self.cronofy_refresh_token)
    cronofy.upsert_event(self.calendar_id, event_data)
  end

  def delete_event(calendar_id, event_id)
    ivr = Ivr.find(self.ivr_id)
    cronofy = ivr.client.create_cronofy(access_token:  self.cronofy_access_token, refresh_token: self.cronofy_refresh_token)
    cronofy.delete_event(calendar_id, event_id)
    EventTrigger.where(event_id: event_id).destroy_all
  end

  def is_connected?
    cronofy ? true : false
  end

  # required params: agenda_customer_id
  def existing_appointments(params = {})
    # reg = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i
    # reg = /\+\w++/i
    reg = /\d+/
    begin
      customer = Customer.find(params[:agenda_customer_id])
      phones = customer.contacts.pluck(:phone).map { |a| a.gsub('+','')} if customer.contacts
    rescue => e
      puts e
      phones = []
    end

    calendar_ids = []
    ivr.client.agenda_apps.each do |agenda|
      agenda_calendars = agenda.all_calendars
      agenda_calendars.each do |calendar|
        calendar_ids.push(calendar[1])
      end
    end

    params.merge!(calendar_ids: calendar_ids)
    params.merge!(include_managed: 1, from: Time.current)
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=classic1 existing appointment-=-=-=-=-=-=-=-=-=-=-=-'
    puts params.inspect

    appointments = []
    events = cronofy.read_events(params) rescue []
    events.each do |appointment|
      (appointment.summary.to_s + ' ' + appointment.description.to_s).scan(reg).uniq.each do |phone|
        appointments << appointment if phones.include? phone.gsub('+','')
      end
    end

    ivr.client.resources.where(ivr_id: params[:current_ivr_id]).each do |resource|
      unless resource.application_access_token.blank?
        params.merge!(calendar_ids: resource.application_calendar_id)
        resource_cronofy = ivr.client.create_cronofy(access_token: resource.application_access_token, refresh_token: resource.application_refresh_token)
        events = resource_cronofy.read_events(params) rescue []
        events.each do |appointment|
          (appointment.summary.to_s+' '+appointment.description.to_s).scan(reg).uniq.each do |phone|
            appointments << appointment if phones.include? phone.gsub('+','')
          end
        end
      end
    end

    puts appointments
    appointments = appointments.map do |a|
      {
          'id' => a['event_id'],
          'time' => DateTime.parse(a['start'].to_s).in_time_zone(customer.client.time_zone),
          'resource' => Appointment.where(event_id: a['event_id'])&.first&.resource_id || customer&.client&.default_resource&.id,
          'service' => Appointment.where(event_id: a['event_id'])&.first&.service_id || customer&.client&.default_service&.id
      }
    end
    appointments.delete_if {|x| x['time'] < Time.current } if appointments
  end

  def get_events(agenda = nil, from, to)
    return [] if agenda.nil?

    params = {}
    calendar_ids = []
    agenda_calendars = agenda.all_calendars
    agenda_calendars.each do |calendar|
      calendar_ids.push(calendar[1])
    end

    params.merge!(calendar_ids: calendar_ids)
    params.merge!(include_managed: 1, from: from, to: to) unless to.nil?
    params.merge!(include_managed: 1, from: from) if to.nil?

    appointments = []
    events = cronofy.read_events(params)
    events.each do |appointment|
      appointments << appointment
    end
    appointments
  rescue => e
    puts e
  end

  def create_channel(callback_url)
    channels = cronofy ? cronofy.list_channels : []
    if channels.count.zero?
      cronofy.create_channel(callback_url)
    else
      channels[0]
    end
  end

  def close_channel(channel_id)
    channels = cronofy ? cronofy.list_channels : []
    unless channels.count.zero?
      cronofy.close_channel(channel_id)
    end
  rescue => e
    puts e
  end

  def existing_appointments_reminders(params = {})
    params.merge!(include_managed: 1, from: Time.current)
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=classic2 existing appointment reminders-=-=-=-=-=-=-=-=-=-=-=-'
    puts params.inspect
    events = cronofy.read_events(params) rescue []
    events
  end

  def delete_appointment(id)
    params = {include_managed: 1, from: Time.current}
    events = cronofy.read_events(params)
    cal_id = ''
    delete_event = nil
    events.each do |event|
      if event['event_id'] == id
        cal_id = event['calendar_id']
        delete_event = event
        break
      end
    end

    params = {event_id: id, calendar_id: cal_id}
    puts params.inspect
    begin
      cronofy.delete_event(cal_id, id)
      response = true
    rescue => e
      puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-delete event-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
      puts e
      if e.message == "404 Not Found"
        exist_appointments = Appointment.where(event_id: id)
        if exist_appointments.count.zero?
          response = false
        else
          resource_id = exist_appointments.first.resource_id
          resource = Resource.find(resource_id)
          application_calendar_id = resource&.application_calendar_id
          application_access_token = resource&.application_access_token
          application_refresh_token = resource&.application_refresh_token

          resource_cronofy = resource.client.create_cronofy(access_token: application_access_token, refresh_token: application_refresh_token)
          events = resource_cronofy.read_events(params)
          events.each do |each|
            if event['event_id'] == id
              delete_event = event
              break
            end
          end
          resource_cronofy.delete_event(application_calendar_id, id)
          response = true
        end

      else
        response = false
      end
    end
    EventTrigger.where(event_id: id).destroy_all

    return {result: response, event: delete_event}
  end

  def services(resource_id: nil)
    if resource_id.present?
      resource = Resource.find_by_id resource_id
      services = Resource.where(id: resource.dependent_ids)
    else
      services = client.services
    end
    services.active.ordered.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def resources(service_id: nil)
    if service_id.present?
      service = Service.find_by_id service_id
      resources = service.resources #Resource.where(id: service.dependent_ids)
    else
      resources = client.resources
    end
    resources.active.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def service(service_id)
    service = client.services.find_by_id(service_id)
    {'id' => service.id, 'name' => service.name}
  end

  def resource(resource_id)
    resource = client.resources.find_by_id(resource_id)
    {'id' => resource.id, 'name' => resource.name}
  end

  # def _id_attr
  #   :id
  # end

  private

  def cronofy(access_token = nil, refresh_token = nil)
    cronofy_access_token = access_token.nil? ? self.cronofy_access_token : access_token
    cronofy_refresh_token = refresh_token.nil? ? self.cronofy_refresh_token : refresh_token
    client = Client.find(self.client_id)

    @cronofy ||= client.create_cronofy(access_token: cronofy_access_token, refresh_token: cronofy_refresh_token)
    @cronofy
  rescue Exception => e
    puts "********************************* cronofy error ****************************************"
    puts e.message
    nil
  end

  def set_default_resource_calendar
    return unless @default_resource_calendar.present?
    default_resource.update(calendar_id: @default_resource_calendar)
  end

  def schedule_for_cronofy(service, resource)
    resource_schedule = resource.use_default_availability? ? default_resource_availability : resource.availability
    service_schedule = service.use_default_availability? ? default_resource_availability : service.availability
    schedule = {}
    if service.disable_schedule?
      schedule = resource_schedule
    elsif resource.disable_schedule?
      schedule = service_schedule
    else
      schedule = common_schedule(resource_schedule,service_schedule)
    end

    schedule
  end

  def common_schedule(resource_schedule,service_schedule)
    resource_schedule
  end
end
