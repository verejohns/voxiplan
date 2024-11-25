# NOT being used
class RasaAction
  attr_accessor :params

  def initialize(session, params)
    @data = session
    @params = params
  end

  def self.perform(session, params)
    new(session, params).send(params[:next_action])
  end

  def data
    @data.symbolize_keys!
  end

  def action_check_availability
    slots = params[:tracker][:slots]
    time_slot = slots[:time]
    day_slot = slots[:date]

    date = time_slot[0..9]
    hour = time_slot[11..15]

    puts "******** current call 2 #{current_call.inspect}"
    slots = current_call.data['free_slots'] rescue {}
    if day_slot.present? && hour.present?

      if slots[join_date_time(day_slot, hour)]
        choosen_time = parse_time(day_slot, hour)
        return  slot_available(choosen_time)
      else
        free_slots = free_slots(after_time)
        slots = current_call.data['free_slots'] rescue {}
      end

    end

    after_time = parse_time(date, hour)
    after_time = after_time if after_time < Time.current
    free_slots = free_slots(after_time)

    events =  [
        {
            "event": "slot",
            "timestamp": nil,
            "name": "time",
            "value": free_slots.present? ? 'available' : nil
        },{
            "event": "slot",
            "timestamp": nil,
            "name": "date",
            "value": date
        },{
            "event": "slot",
            "timestamp": nil,
            "name": "hour",
            "value": hour == "00:00" ? nil : hour
        }
    ]

    if free_slots.blank?
      text = I18n.t('ai_bot.slot_not_available')
    elsif free_slots.count == 1
      return slot_available(free_slots[0]['start'])
    else
      text = I18n.t('ai_bot.available_free_slots', times(free_slots))
    end

    {
        "events": events,
        "responses": [
            {"text": text}
        ]
    }
  end

  def action_make_appointment
    slots = params[:tracker][:slots]
    hour_slot = slots[:hour]
    day_slot = slots[:date]
    choosen_time = parse_time(day_slot, hour_slot)
    time = I18n.l(choosen_time, format: :custom, locale: :en, day: choosen_time.day, greek_month: GreekMonth.genitive(time.month))

    free_slots = current_call.data['free_slots'] rescue {}
    params = free_slots[join_date_time(day_slot, hour_slot)]
    params.merge! common_required_attributes

    params.transform_values! do |v|
      date_regx = '[0-9]{4}-[0-9]{2}-[0-9]{2}'
      time_regx = "#{date_regx}T[0-9]{2}:[0-9]{2}"
      if v.match?(/#{time_regx}/)
        Time.parse v
      elsif v.match?(/#{date_regx}/)
        Date.parse v
      else
        v
      end
    end

    if agenda_app.create_appointment(params)
      text = I18n.t('ai_bot.appointment_success', time: time)
    else
      text = I18n.t('ai_bot.appointment_failed')
    end

    {
        "responses": [
            {"text": text}
        ]
    }
  end


  private


  def slot_available(time)

    local_time = I18n.l(time, format: :custom, locale: :en, day: time.day, greek_month: GreekMonth.genitive(time.month))
    {
        "events": [
            {
                "event": "slot",
                "timestamp": nil,
                "name": "confirm_slot",
                "value": 'true'
            },{
                "event": "slot",
                "timestamp": nil,
                "name": "date",
                "value": time.strftime('%F')
            },{
                "event": "slot",
                "timestamp": nil,
                "name": "hour",
                "value": time.strftime('%H:%M')
            }
        ],
        "responses": [
            {"text": I18n.t('ai_bot.slot_available', time: local_time)}
        ]
    }
  end

  def common_required_attributes
    attrs = { agenda_customer_id: current_customer.eid, caller_id: data[:caller_id] }
    agenda_app.common_required_attrs(attrs)
  end

  def times(free_slots)
    ret ={}
    3.times do |i|
      ret["time#{i+1}".to_sym] = free_slots[i] ? I18n.l(free_slots[i]['start'], format: :hour, locale: :en) : nil
    end
    ret
  end

  def free_slots(after_time)
    # TODO: Make it dynamic
    service = ivr.services.first
    resource = service.resources.first

    constraints = {
        full_day: true, weekday: nil,
        ampm: nil, time_slot: nil,
        service_id: service.eid,
        resource_id: resource.eid
    }

    time = after_time #Time.parse(after_time)
    slots = agenda_app.free_slots(100, time, constraints)

    free_slots = {}
    slots.each do |slot|
      key = slot['start'].strftime "%FT%R" # "2019-01-01T19:30"
      free_slots[key] = agenda_app.required_attrs slot
    end

    data[:free_slots] = free_slots
    current_call.data[:free_slots] = free_slots
    current_call.save
    slots
  end

  def parse_time(date, time)
    Time.parse(join_date_time(date, time))
  end

  def join_date_time(date, time)
    "#{date}T#{time}"
  end

  def current_call
    @current_call ||= Call.find(data[:current_call_id])
  end

  def current_customer
    Customer.find_by(id: data[:current_customer_id]) || Customer.first
  end

  def ivr
    @ivr ||= current_call.ivr
  end

  def dummy_agenda
    dummy_agenda = DummyAgenda::new
    dummy_agenda.ivr_id = nil
    dummy_agenda.client_id = ivr.client.id
    dummy_agenda
  end

  def agenda_app
    ivr.client.agenda_apps.count.zero? ? dummy_agenda : ivr.client.agenda_apps.first
  end
end