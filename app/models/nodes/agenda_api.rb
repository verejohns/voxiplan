class AgendaApi < Node
  TimeFrameRange = {
                      minutes:  0..60,
                      hours:    0..6,
                      days:     1..90,
                      weeks:    1..8,
                      months:   1..24
                    }
  TimeFrame =  [
                      ["minutes", "Minute"],
                      ["hours", "Hour"],
                      ["days", "Day"],
                      ["weeks", "Week"],
                      ["months", "Month"]
                    ]
  def execute

    case method_name
      when 'free_slots'
        call_free_slots
      when 'slot_groups'
        call_groups
      when 'services'
        call_services
      when 'resources'
        call_resources
      when 'choose_selected'
        choose_selected
      when 'make_appointment'
        call_make_appointment
      when 'existing_caller'
        check_existing_caller
      when 'create_new_caller'
        create_new_caller
      when 'existing_appointments'
        existing_appointments
      when 'cancel_appointment'
        cancel_appointment
      when 'can_cancel_or_modify'
        can_cancel_or_modify
    end
  end

  private

  def save_slot_data(slots, results)
    slots.each_with_index do |slot,i|
      break unless results[i]
      sid = results[i]['sid']
      data[sid] = agenda_app.required_attrs slot
      results[i].except('sid').each do |k,v|
        data[v.to_sym] = slot[k]
      end
    end
    save_data(slots.count, key: :slot_count)
  end

  def call_free_slots
    num = parameters['number_of_slots']
    time = Time.parse(parameters['after_time'] % data) + 5.seconds

    options = parameters['options'].transform_values{|v| interpolated_value(v) } if parameters['options']
    options["service_id"] = Ivr.find(data[:current_ivr_id]).services.first.id.to_s if options["service_id"].blank? || options["service_id"].nil?
    options["resource_id"] = Ivr.find(data[:current_ivr_id]).resources.first.id.to_s if options["resource_id"].blank? || options["resource_id"].nil?

    puts '-=-=-=-=-Options for tracing of split error-=-=-=-=-'
    puts options.inspect
    puts '-=-=-=-=-End tracing-=-=-=-=-'
    
    if options && options['weekday']
      weekday = options['weekday'].to_i
      time += (1 + ((weekday - 1 - time.wday) % 7)).day if weekday
    end

    slots = agenda_app.free_slots(num, time, options)
    save_slot_data(slots, results)

    if slots.count == 0
      invalid_next_node.run(@options)
    else
      next_node.run(@options.merge(slot_count: slots.count))
    end
  end

  def common_required_attributes
    if data[:choosen_service].blank? || data[:choosen_service].nil?
      duration = 30.minutes
    else
      if agenda_app.type == 'ClassicAgenda' || agenda_app.type == 'DummyAgenda'
        duration = Service.find_by(id: data[:choosen_service], client_id: data[:client_id]).duration * 60
      else
        duration = Service.find_by(eid: data[:choosen_service], client_id: data[:client_id]).duration * 60
      end
    end
    attrs = { customer_id: current_customer.id, agenda_customer_id: current_customer.eid, caller_id: data[:caller_id],
              existing_appointment_id: data[:choosen_existing_appointment_id], start: data[:choosen_slot_start],
              finish: data[:choosen_slot_start] + duration,
              resource: data[:choosen_resource], service: data[:choosen_service] }
    agenda_app.common_required_attrs(attrs)
  end

  def resource_user_email(resource, email_host_body, email_host_subject, type)
    if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
      team_client = Client.find(resource.team_calendar_client_id)
      if team_client
        template_data_team_client = {
          title: type == "confirm" ? I18n.t("mails.client_appointment_confirmed.title") : I18n.t("mails.confirmation.body_line8"),
          body: email_host_body,
          subject: email_host_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }

        options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_team_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end
    end
  end

  def call_make_appointment
    params = interpolated_values(self.parameters['sid'])
    params.merge! common_required_attributes
    event_id = data[:choosen_existing_appointment_id]
    params.merge!(evt_id: event_id.presence || "")
    params[:service] = ResourceService.where(resource_id: params[:resource].to_i).first&.service_id.to_s if params[:service].nil? || params[:service].blank?

    # [:start, :finish].each{|t| params[t] = Time.parse params[t]}
    # params[:caller_id] = data[:caller_id] # only used in Supersaas use common_required_attributes
    created = agenda_app.create_appointment(params)
    puts "************** created_appointment *********************"
    puts created
    puts params
    if created[:result]
      appointment_type = event_id.present? ? 'modified' : 'new'
      attr = { appointment_time: data[:choosen_slot_start], appointment_type: appointment_type }
      current_call.update(attr)
      begin
        event = created[:event]

        if agenda_app.type == 'Mobminder'
          event_start = params[:cueIn]
        elsif agenda_app.type == 'Timify'
          event_start = params[:datetime]
        else
          event_start = event[:start]
        end
        event_date_time = event_start.to_time.in_time_zone(current_call.ivr.client.time_zone)
        event_date = I18n.localize(event_date_time.to_date, format: :long, locale: current_call.ivr.voice_locale)
        event_time = event_date_time.strftime("%I:%M %p")
        event_day = event_date_time.strftime("%A")

        appointment = Appointment.find_by_event_id(event_id)

        if event_id && appointment
          client = appointment.client
          customer = Customer.find(appointment.caller_id)
          if agenda_app.type == 'Mobminder' || agenda_app.type == 'Timify'
            resource = current_call.ivr.resources.where(eid: appointment.resource_id).first
            service = current_call.ivr.services.where(eid: appointment.service_id).first
            event_name = service.name
          else
            resource = Resource.find(appointment.resource_id)
            service = Service.find(appointment.service_id)
            event_name = event[:summary]
          end
        else
          if agenda_app.type == 'Mobminder' || agenda_app.type == 'Timify'
            customer = Customer.find_by_eid(agenda_app.type == 'Mobminder' ? params[:visitors] : params[:customer_id])
            service = current_call.ivr.services.where(eid: agenda_app.type == 'Mobminder' ? params[:service] : params[:service_id]).first
            resource = current_call.ivr.resources.where(eid: agenda_app.type == 'Mobminder' ? params[:resource] : params[:resource_ids][0]).first
            event_name = service.name
          else
            customer = Customer.where(id: params[:customer_id].to_i).count > 0 ? Customer.find(params[:customer_id].to_i) : Customer.find_by_eid(params[:customer_id])
            service = Service.find(params[:service])
            resource = Resource.find(params[:resource] || params[:resource_id])
            event_name = event[:summary]
          end
          client = customer.client
        end

        if appointment_type == 'modified'
          email_invitee_notification = ServiceNotification.where(service_id: service.id, automation_type: appointment_type == 'modified' ? 'rescheduling_email_invitee' : 'confirmation_email_invitee')
          if email_invitee_notification.count.zero?
            email_invitee_subject = appointment_type == 'new' ? I18n.t("mails.confirmation_email_invitee.subject") : I18n.t("mails.rescheduling_email_invitee.subject")
            email_invitee_body = appointment_type == 'new' ? I18n.t("mails.confirmation_email_invitee.body").html_safe : I18n.t("mails.rescheduling_email_invitee.body").html_safe
          else
            email_invitee_subject = email_invitee_notification.first.subject
            email_invitee_body = email_invitee_notification.first.text
          end

          email_invitee_body = email_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                     first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}

          template_data_invitee = {
            title: appointment_type == 'new' ? I18n.t("mails.client_appointment_confirmed.title") : I18n.t("mails.confirmation.body_line8"),
            body: email_invitee_body,
            subject: email_invitee_subject,
            copyright: I18n.t("mails.copyright"),
            reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
          }

          if customer && customer.email.present?
            options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: client.email, reply_to_name: client.full_name }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
          end

          email_host_notification = ServiceNotification.where(service_id: service.id, automation_type: appointment_type == 'modified' ? 'rescheduling_email_host' : 'confirmation_email_host')
          if email_host_notification.count.zero?
            use_email_host = false
            email_host_subject = appointment_type == 'new' ? I18n.t("mails.confirmation_email_host.subject") : I18n.t("mails.rescheduling_email_host.subject")
            email_host_body = appointment_type == 'new' ? I18n.t("mails.confirmation_email_invitee.body").html_safe : I18n.t("mails.rescheduling_email_invitee.body").html_safe
          else
            use_email_host = email_host_notification.first.use_email_host
            email_host_subject = email_host_notification.first.subject
            email_host_body = email_host_notification.first.text
          end

          email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}

          template_data_host = {
            title: appointment_type == 'new' ? I18n.t("mails.client_appointment_confirmed.title") : I18n.t("mails.confirmation.body_line8"),
            body: email_host_body,
            subject: email_host_subject,
            copyright: I18n.t("mails.copyright"),
            reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
          }

          if use_email_host
            options = { to: client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_host }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

            resource_user_email(resource, email_host_body, email_host_subject, "confirm")
          end

          sms_invitee_notification = ServiceNotification.where(service_id: service.id, automation_type: appointment_type == 'new' ? 'confirmation_sms_invitee' : 'rescheduling_sms_invitee')

          if sms_invitee_notification.count.zero?
            use_sms_invitee = false
            sms_invitee_body = appointment_type == 'new' ? I18n.t("mails.confirmation_sms_invitee.body").html_safe : I18n.t("mails.rescheduling_sms_invitee.body")
          else
            use_sms_invitee = sms_invitee_notification.first.use_sms_invitee
            sms_invitee_body = sms_invitee_notification.first.text
          end
          sms_invitee_body = sms_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                 first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name,
                                                 choosen_slot_start: event_date, choosen_existing_appointment_time: event_date + ' at ' + event_time, caller_id: customer.full_name}

          sms_host_notification = ServiceNotification.where(service_id: service.id, automation_type: appointment_type == 'new' ? 'confirmation_sms_host' : 'rescheduling_sms_host')

          if sms_host_notification.count.zero?
            use_sms_host = false
            sms_host_body = appointment_type == 'new' ? I18n.t("mails.confirmation_sms_host.body").html_safe : I18n.t("mails.rescheduling_sms_host.body")
          else
            use_sms_host = sms_host_notification.first.use_sms_host
            sms_host_body = sms_host_notification.first.text
          end
          sms_host_body = sms_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                           first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name,
                                           choosen_slot_start: event_date, choosen_existing_appointment_time: event_date + ' at ' + event_time, caller_id: customer.full_name}
          puts "************** created_sms *********************"
          puts sms_invitee_body.gsub(/<[^>]*>/,'')
          puts sms_host_body.gsub(/<[^>]*>/,'')
          send_sms_to_user(customer.phone_number, sms_invitee_body.gsub(/<[^>]*>/,'')) if use_sms_invitee && is_valid_mobile(customer.phone_number)
          send_sms_to_user(current_call.ivr.client.phone, sms_host_body.gsub(/<[^>]*>/,'')) if use_sms_host && is_valid_mobile(current_call.ivr.client.phone)

          re_appointment = Appointment.where(event_id: event_id).first
          rescheduled_count = re_appointment.rescheduled_count ? re_appointment.rescheduled_count + 1 : 1
          re_appointment.update_columns(time: current_call.appointment_time, status: "Rescheduled", rescheduled_count: rescheduled_count)
        else
          # set automation variable for sms
          @options[:session_data][:event_name] = event_name
          @options[:session_data][:event_day] = event_day
          @options[:session_data][:event_date] = event_date
          @options[:session_data][:event_time] = event_time
          @options[:session_data][:first_name] = customer.first_name
          @options[:session_data][:last_name] = customer.last_name
          @options[:session_data][:full_name] = customer.full_name
          @options[:session_data][:resource_name] = resource.name
          @options[:session_data][:choosen_existing_appointment_time] = event_date + ' at ' + event_time
          puts "************** @options **************"
          puts @options
          Appointment.create(caller_id: customer.id, caller_name: customer.full_name,
            time: current_call.appointment_time, tropo_session_id: nil, client_id: current_call.ivr.client.id, source: 'IVR', ivr_id: current_call.ivr.id,
            resource_id: agenda_app.type == 'Timify' ? params[:resource_ids][0] : params[:resource], service_id: agenda_app.type == 'Timify' ? params[:service_id] : params[:service], event_id: event[:event_id], status: "Confirmed")
        end
      rescue Exception => e
        puts e
      end
      next_node.run(@options)
    else
      invalid_next_node.run(@options)
    end
  end

  # returns array of groups
  # use next to fetch more groups
  # [{day: 'today', start: '9 AM', finish: '7 PM', next: '2018-03-25 00:00'}]
  def call_groups
    num = parameters['number_of_groups']
    time = get_after_time(parameters['after_time'])

    options = parameters['options'].transform_values{|v| interpolated_value(v) } if parameters['options']
    options["service_id"] = Ivr.find(data[:current_ivr_id]).services.first.id.to_s if options["service_id"].blank? || options["service_id"].nil?
    options["resource_id"] = Ivr.find(data[:current_ivr_id]).resources.first.id.to_s if options["resource_id"].blank? || options["resource_id"].nil?

    slot_results = parameters['slot_results']
    groups = agenda_app.groups(num, time, options)
    groups = groups.each_with_index.map do |group, index|
      date, slots = group
      if slots.count == 1
        save_slot_data(slots.first(1), [slot_results[index]])
      end
      {
        'day' => get_day(date),
        'start' => get_hour(slots.first['start']),
        'finish' => get_hour(slots.last['start']),
        'date' => (date).to_time,
        'next_date' => (date + 1.day).to_time,
        'slot_count' => slots.count
      }
    end

    puts groups.to_yaml
    results.each_with_index do |r,i|
      r.each do |k,v|
        data[v.to_sym] = groups[i][k] if groups[i].present?
      end
    end
    next_node.run(@options.merge(slot_count: groups.count))
  end

  def call_services
    resource = parameters['resource'] % data rescue nil
    services = agenda_app.active_services(resource_id: resource, ivr_id: data[:current_ivr_id])
    # services = agenda_app.services(resource_id: resource)

    save_data(services.count, key: :service_count)

    services.each_with_index do |service, index|
      results.each do |k,v|
        data["#{v}#{index+1}".to_sym] = service[k]
      end
    end
    next_node.run(@options.merge(slot_count: services.count))
  end

  def call_resources
    service = parameters['service'] % data rescue nil
    resources = agenda_app.active_resources(service_id: service, ivr_id: data[:current_ivr_id])
    # resources = agenda_app.resources(service_id: service)

    save_data(resources.count, key: :resource_count)
    store_results(resources)
    next_node.run(@options.merge(slot_count: resources.count))
  end

  def store_results(results)
    results.each_with_index do |resource, index|
      self.results.each do |k,v|
        data["#{v}#{index+1}".to_sym] = resource[k]
      end
    end
  end

  def choose_selected
    selected_num = interpolated_value(parameters['selected'])
    if self.parameters['keys']
      self.parameters['keys'].each do |key|
        value = interpolated_value "%{#{parameters['prefix']}_#{key}#{selected_num}}"
        save_data(value, key: "#{parameters['save_as']}_#{key}".to_sym)
      end
    else
      value = interpolated_value "%{#{parameters['prefix']}#{selected_num}}"
      save_data(value, key: parameters['save_as'].to_sym)
    end
    next_node.run(@options)
  end

  def check_existing_caller
    existing_caller = agenda_app.find_and_create_customer(data[:caller_id], data[:client_id]) rescue false
    puts "****************** existing_caller *********************"
    puts existing_caller.inspect
    if existing_caller
      current_call.returning_client!
      set_current_customer(existing_caller)
      next_node.run(@options)
    else
      current_call.update_column(:client_type, 'new')#.new_client!
      invalid_next_node.run(@options)
    end
  rescue Exception => e
    puts "************ check_existing_caller *************"
    puts e.message
  end

  def existing_appointments
    current_call.call_for_appointment!
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-visitor id data-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'

    unless current_call.ivr.client.agenda_apps.count.zero?
      customer = current_call.ivr.client.agenda_apps.first.find_customer(phone: data[:caller_id], client_id: current_call.ivr.client.id) if ['ClassicAgenda','Mobminder'].include? current_call.ivr.client.agenda_apps.first.type
    end
    eid = current_customer.eid.presence || customer.try(:eid).presence || customer.try(:id)
    eid = current_customer.id if eid.nil?
    begin
      if current_call.ivr.client.agenda_apps.count.zero?
        # for DummyAgenda
        c_id = current_call.ivr.resources.pluck(:application_calendar_id).uniq.compact
      else
        # for ClassicAgenda
        c_id = (current_call.ivr.resources.pluck(:calendar_id) << current_call.ivr.client.agenda_apps.first.default_resource_calendar).uniq.compact
      end

    rescue Exception => e
      puts e
      c_id = nil
    end

    params = {agenda_customer_id: eid}
    params.merge!(calendar_ids: c_id) if c_id || (current_call.ivr.client.agenda_apps.count > 0 && current_call.ivr.client.agenda_apps.first.type == 'ClassicAgenda')
    params.merge!(current_ivr_id: data[:current_ivr_id])
    puts '=============params----------------'
    puts params.inspect
    appointments = agenda_app.existing_appointments(params)
    puts '==================appointments fetched from calendar======================='
    puts appointments.inspect
    # appointments = agenda_app.existing_appointments(agenda_customer_id: eid)
    # appointments = agenda_app.existing_appointments(agenda_customer_id: current_customer.eid)
    store_results appointments
    save_data(appointments.count, key: :existing_appointment_count)
    next_node.run(@options.merge(slot_count: appointments.count))
  end

  def can_cancel_or_modify
    existing_appointment_time = interpolated_value "%{#{parameters['choosen_existing_appointment']}}"
    puts '==================cancel_or_modify=================='
    puts existing_appointment_time
    max_cancelable_time = existing_appointment_time - time_offset(self.ivr.preference['cancel_time_offset'])
    save_data(Time.current < max_cancelable_time)
    next_node.run(@options)
  end

  def cancel_appointment
    existing_appointment_id = interpolated_value "%{#{parameters['existing_appointment']}_id}"
    # appointment_resource_id = interpolated_value "%{#{parameters['existing_appointment']}_resource}"

    if existing_appointment_id.nil?
      next_node.run(@options)
    else
      deleted = agenda_app.delete_appointment(existing_appointment_id)
      puts "************** cancelled_appointment *********************"
      puts deleted
      if deleted[:result]
        current_call.cancelled_appointment!
        event = deleted[:event]

        appointment = Appointment.find_by_event_id(existing_appointment_id)
        if agenda_app.type == 'Mobminder' || agenda_app.type == 'Timify'
          resource = current_call.ivr.resources.where(eid: appointment.resource_id).first
          service = current_call.ivr.services.where(eid: appointment.service_id).first
          event_start = agenda_app.type == 'Mobminder' ? event[:cueIn] : appointment.time
          event_name = service.name
        else
          resource = Resource.find(appointment.resource_id)
          service = Service.find(appointment.service_id)
          event_start = appointment.time
          event_name = service.name
        end
        client = appointment.client
        customer = Customer.find(appointment.caller_id)
        event_date_time = event_start.to_time.in_time_zone(current_call.ivr.client.time_zone)
        event_date = I18n.localize(event_date_time.to_date, format: :long, locale: current_call.ivr.voice_locale)
        event_time = event_date_time.strftime("%I:%M %p")
        event_day = event_date_time.strftime("%A")

        email_invitee_notification = ServiceNotification.where(service_id: service.id, automation_type: 'cancellation_email_invitee')
        email_invitee_subject = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.subject') : email_invitee_notification.first.subject
        email_invitee_body = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.body') : email_invitee_notification.first.text
        email_invitee_body = email_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                   first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
        template_data_invitee = {
          title: I18n.t("mails.cancellation_email_invitee.title"),
          body: email_invitee_body,
          subject: email_invitee_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }
        if customer && customer.email.present?
          options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_CANCEL'], template_data: template_data_invitee, reply_to_email: client.email, reply_to_name: client.full_name }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
        end

        email_host_notification = ServiceNotification.where(service_id: service.id, automation_type: 'cancellation_email_host')
        email_host_subject = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.subject') : email_host_notification.first.subject
        email_host_body = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.body') : email_host_notification.first.text
        email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                   first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
        use_email_host = email_host_notification.count.zero? ? false : email_host_notification.first.use_email_host
        template_data_host = {
          title: I18n.t("mails.cancellation_email_invitee.title"),
          body: email_host_body,
          subject: email_host_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }
        if use_email_host
          options = { to: client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_host }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

          if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
            team_client = Client.find(resource.team_calendar_client_id)
            if team_client
              team_client_email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                               first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}

              template_data_team_client = {
                title: I18n.t("mails.cancellation_email_invitee.title"),
                body: team_client_email_host_body,
                subject: email_host_subject,
                copyright: I18n.t("mails.copyright"),
                reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
              }

              options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_CANCEL'], template_data: template_data_team_client }
              SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
            end
          end
        end
        # set automation variable for sms
        @options[:session_data][:event_name] = event_name
        @options[:session_data][:event_day] = event_day
        @options[:session_data][:event_date] = event_date
        @options[:session_data][:event_time] = event_time
        @options[:session_data][:first_name] = customer.first_name
        @options[:session_data][:last_name] = customer.last_name
        @options[:session_data][:full_name] = customer.full_name
        @options[:session_data][:resource_name] = resource.name
        puts "************** cancelled @options **************"
        puts @options

        Appointment.where(event_id: existing_appointment_id).update_all(status: "Cancelled")
        next_node.run(@options)
      else
        invalid_next_node.run(@options)
      end
    end

  end

  def send_sms_to_user(to, message)
    telephony_name = current_call.ivr.preference['sms_engin'] || 'twilio'
    telephony = TropoEngine.new({}) if telephony_name == 'tropo'
    telephony = TwilioEngine.new({}) if telephony_name == 'twilio'
    telephony = VoxiSMSEngin.new({}) if telephony_name == 'voxi_sms'

    sms = TextMessage.create({to: Phonelib.parse(to).e164, content: message, sms_type: 'single_sms', ivr: current_call.ivr})
    telephony.send_sms(sms.id)
  end

  def is_valid_mobile(phone_no)
    phone = Phonelib.parse(phone_no)
    (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile)) rescue false
  end

  def create_new_caller
    customer = find_or_create_customer
    if customer
      # CreateCustomerOnAgendaJob.perform_later(customer.id, agenda_app.id) unless customer.created_on_agenda?
      unless customer.created_on_agenda?
        begin
          agenda_app.create_customer_on_agenda(customer.id)
          customer.update(created_on_agenda: true )
        rescue Exception => e
          logger.error "XXXXXX Exception while creating customer on Agenda #{agenda_app.id}."
          puts e.message
          puts e.backtrace
        end
      end
      set_current_customer(customer)
      next_node.run(@options)
    else
      invalid_next_node.run(@options)
    end
  end

  private

  def find_or_create_customer
    recorded_user_name = interpolated_value(parameters['recorded_user_name'])
    # trying to extract country info from caller_id. Should work fine if Tropo is returning valid e164
    phone = parse_phone(data[:caller_id])

    contact = self.ivr.client.contacts.find_by(phone: phone.e164)
    return contact.customer if contact

    type = phone.type == :mobile ? :phone_number : :fixed_line_num

    Customer.create(
      type => voxi_phone(phone),
      phone_country: phone.country,
      recorded_name_url: recorded_user_name,
      client: self.ivr.client,
      lang: self.ivr.voice_locale,
      phone_number: phone.e164,
      contacts_attributes: [{phone: phone.e164, country: phone.country, client_id: self.ivr.client.id}]
    )
  end

  def time_offset(str)
    key = interpolated_keys(str).to_s
    result = key.scan(/(\d+)_(minute|hour|day|week|month)S*/i)
    return 0 unless result.present?
    duration, method = result.first
    duration.to_i.send(method)
  end

  def get_after_time(str)
    time_offset = time_offset(str)

    if time_offset > 0
      time = Time.current + time_offset
      time_offset >= 1.day ? time.midnight : time
    else
      # Time.parse(str % data) + 5.seconds
      key = interpolated_keys(str).to_s
      if data.has_key?(key) || data.has_key?(key.to_sym)
        Time.parse(str % data) + 5.seconds
      else
        time = Time.current + 5.seconds
      end
    end
  end

  def set_current_customer(customer)
    # current_call.save_data(:current_customer_id, customer.id)
    data[:current_customer_id] = customer.id
    data[:customer_first_name] = customer_first_name(customer)
  end

  def customer_first_name(customer)
    if customer.first_name.present? && customer.first_name != 'Voxiplan'
      customer.first_name
    elsif ivr.preference['say_recorded_name']
      " #{customer.recorded_name_url} " # a space is required by Tropo to properly speak from UR.
    end
  end

  def get_day(date)
    if date.today?
      I18n.t('date.today', locale: locale_from_voice)
    elsif date == Date.current.tomorrow
      I18n.t('date.tomorrow', locale: locale_from_voice)
    else
      formatted_time(date, format: :weekday_and_num)
    end
  end

  def get_hour(time)
    formatted_time(time, format: :hour)
  end



  # def results
  #       [{start: 'slot1_start', finish: 'slot1_end'},
  #        {start: 'slot2_start', finish: 'slot2_end'}]
  # end

end
