class AppointmentReminderJob < ApplicationJob
  queue_as :default

  def perform
    list = ['days', 'weeks', 'months']
    sameday_reminders = Reminder.where(advance_time_duration: '-')
    reminders = Reminder.where(advance_time_duration: list)
    reg = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i
    # reg1 = /\+\w++/i
    reg1 = /\d+/

    # same_day_reminder(sameday_reminders, reg, reg1)
    send_reminder(reminders, reg, reg1)
  end

  def send_reminder(reminders, reg, reg1)
    reminders.each do |reminder|
      puts "******************* reminder send_reminder *********************"
      puts reminder.inspect
      ivr = reminder.ivr
      next if ivr.nil? || reminder.enabled == false || reminder.enabled.nil?

      now_time = Date.current.strftime('%d-%m-%Y') + ' ' + reminder.time + ' ' + Time.now.in_time_zone(ivr.client.time_zone).formatted_offset
      start_time = Time.at((Time.current.to_f / 30.minutes).floor * 30.minutes).utc
      new_start = Time.parse(start_time.strftime('%d-%m-%Y')).utc
      new_start = latest_start(new_start, reminder.advance_time_duration, reminder.advance_time_offset)
      puts "******************* start_time *********************"
      puts start_time
      puts new_start
      params = {}
      params.merge!(calendar_ids: [])
      params.merge!(include_managed: 1, from: new_start)

      appointments = []
      if reminder.is_include_agenda
        agenda_apps = ivr.client.agenda_apps.where(type: 'ClassicAgenda')
        agenda_apps.each do |agenda|
          if agenda.type == 'ClassicAgenda' && agenda.cronofy_access_token.present?
            events = agenda.get_events(agenda, new_start, nil)
            events.map{ |event| appointments << event } unless events.nil?
          end
        end

        ivr.client.application_calendars.each do |application_calendar|
          get_application_events(params, application_calendar).map{ |event| appointments << event }
        end
      end

      appointments.delete(nil)
      agenda_appointments = appointments
      next if agenda_appointments.nil?

      agenda_appointments.each do |agenda_appointment|
        puts "******************* agenda_appointment *********************"
        puts agenda_appointment.inspect
        puts "******************* agenda_appointment_start_time *********************"
        puts agenda_appointment.start.to_time
        service_appointment = reminder.service_id.zero? ? Appointment.where(event_id: agenda_appointment.event_id) : Appointment.where(event_id: agenda_appointment.event_id, service_id: reminder.service_id)
        if service_appointment.count > 0 && Time.parse(now_time).utc == start_time && agenda_appointment.start.to_time <= new_start+1.day && agenda_appointment.start.to_time >= new_start
          resource = Resource.find(service_appointment.first.resource_id)
          replace_options = { event_name: agenda_appointment.summary,
                             event_day: formatted_day(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             event_date: formatted_date(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             event_time: formatted_hour(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             first_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.first_name,
                             last_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.last_name,
                             full_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.full_name,
                             resource_name: resource.name }

          reminder_text = reminder.text % replace_options
          reminder_subject = reminder.email_subject % replace_options

          cancel_link = reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: agenda_appointment.event_id, type: 'cancel') : ''
          reschedule_link = reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: agenda_appointment.event_id, type: 'schedule') : ''
          # if cancel_link.present?
          #   reminder_text = reminder_text + "<br><br>" + I18n.t('mails.cancel_reschedule_text') + "<br>" +
          #     I18n.t('mails.cancel_link_text') + ": " + cancel_link + "<br>" +
          #     I18n.t('mails.reschedule_link_text') + ": " + reschedule_link
          # end

          if reminder.email
            reminder_text_host = reminder.text_host % replace_options
            reminder_subject_host = reminder.email_subject_host % replace_options

            template_data_client = {
              title: t("mails.client_appointment_confirmed.title"),
              body: reminder_text_host,
              subject: reminder_subject_host || 'Reminder',
              copyright: t("mails.copyright"),
              reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
            }

            options = { to: ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

            if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
              team_client = Client.find(resource.team_calendar_client_id)
              if team_client
                options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
                SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
              end
            end
          end

          template_data_invitee = {
            title: t("mails.client_appointment_confirmed.title"),
            body: reminder_text,
            subject: reminder_subject || 'Reminder',
            cancel_link: cancel_link,
            reschedule_link: reschedule_link,
            copyright: t("mails.copyright"),
            reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
          }

          agenda_appointment.description.scan(reg).uniq.each do |email|
            # send_email(email, reminder_text, reminder.email_subject || 'Reminder', formatted_date(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), formatted_hour(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), ivr.client.email)
            options = { to: email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: ivr.client.email, reply_to_name: ivr.client.full_name }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
          end

          sms_text = reminder.sms_text % replace_options
          if reminder.sms
            (agenda_appointment.summary.to_s + ' ' + agenda_appointment.description.to_s).scan(reg1).uniq.each do |phone|
              send_sms(ivr, phone, sms_text)
            end
          end
        end
      rescue => e
        puts e
      end
    end
  end

  def same_day_reminder(reminders,reg,reg1)
    reminders.each do |reminder|
      puts "******************* reminder same_day_reminder *********************"
      puts reminder.inspect
      ivr = reminder.ivr
      next if ivr.nil? || reminder.enabled == false || reminder.enabled.nil?

      params = {}
      params.merge!(calendar_ids: [])
      params.merge!(include_managed: 1, from: Time.current)

      appointments = []
      agenda_apps = ivr.client.agenda_apps.where(type: 'ClassicAgenda')
      agenda_apps.each do |agenda|
        if agenda.type == 'ClassicAgenda' && agenda.cronofy_access_token.present?
          events = agenda.get_events(agenda, Time.current, nil)
          events.map{ |event| appointments << event } unless events.nil?
        end
      end

      ivr.client.application_calendars.each do |application_calendar|
        get_application_events(params, application_calendar).map{ |event| appointments << event }
      end
      appointments.delete(nil)

      start_time = Time.at((Time.current.to_f / 10.minutes).floor * 10.minutes).utc
      start_time = start_time + (reminder.advance_time_offset.to_i).minutes
      puts "******************* start_time *********************"
      puts start_time

      agenda_appointments = appointments
      next if agenda_appointments.nil?

      agenda_appointments.each do |agenda_appointment|
        puts "******************* agenda_appointment *********************"
        puts agenda_appointment.inspect
        puts "******************* agenda_appointment_start_time *********************"
        puts agenda_appointment.start.to_time

        service_appointment = reminder.service_id.zero? ? Appointment.where(event_id: agenda_appointment.event_id) : Appointment.where(event_id: agenda_appointment.event_id, service_id: reminder.service_id)
        if service_appointment.count > 0 && agenda_appointment.start.to_time == start_time #agenda_appointment.start.to_time.between?(from, to)
          resource = Resource.find(service_appointment.first.resource_id)
          replace_options = { event_name: agenda_appointment.summary,
                             event_day: formatted_day(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             event_date: formatted_date(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             event_time: formatted_hour(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale),
                             first_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.first_name,
                             last_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.last_name,
                             full_name: Customer.where(id: Appointment.find_by_event_id(agenda_appointment.event_id)&.caller_id&.to_i)&.first&.full_name,
                             resource_name: resource.name }

          reminder_text = reminder.text % replace_options
          reminder_subject = reminder.email_subject % replace_options

          cancel_link = reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: agenda_appointment.event_id, type: 'cancel') : ''
          reschedule_link = reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: agenda_appointment.event_id, type: 'schedule') : ''
          # if cancel_link.present?
          #   reminder_text = reminder_text + "<br><br>" + I18n.t('mails.cancel_reschedule_text') + "<br>" +
          #     I18n.t('mails.cancel_link_text') + ": " + cancel_link + "<br>" +
          #     I18n.t('mails.reschedule_link_text') + ": " + reschedule_link
          # end

          if reminder.email
            reminder_text_host = reminder.text_host % replace_options
            reminder_subject_host = reminder.email_subject_host % replace_options

            template_data_client = {
              title: t("mails.client_appointment_confirmed.title"),
              body: reminder_text_host,
              subject: reminder_subject_host || 'Reminder',
              copyright: t("mails.copyright"),
              reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
            }

            options = { to: ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

            if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
              team_client = Client.find(resource.team_calendar_client_id)
              if team_client
                options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
                SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
              end
            end
          end

          template_data_invitee = {
            title: t("mails.client_appointment_confirmed.title"),
            body: reminder_text,
            subject: reminder_subject || 'Reminder',
            cancel_link: cancel_link,
            reschedule_link: reschedule_link,
            copyright: t("mails.copyright"),
            reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
          }

          agenda_appointment.description.scan(reg).uniq.each do |email|
            # send_email(email, reminder_text, reminder.email_subject || 'Reminder', formatted_date(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), formatted_hour(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), ivr.client.email)
            options = { to: email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: ivr.client.email, reply_to_name: ivr.client.full_name }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
          end

          sms_text = reminder.sms_text % replace_options
          if reminder.sms
            (agenda_appointment.summary.to_s + ' ' + agenda_appointment.description.to_s).scan(reg1).uniq.each do |phone|
              send_sms(ivr, phone, sms_text) if phone.length >= 10
            end
          end
        end
      rescue => e
        puts e
      end
    end
  end

  def get_application_events(params, application_calendar)
    applcation_calendar_appointments = []
    unless application_calendar.access_token.blank?
      params.merge!(calendar_ids: application_calendar.calendar_id)

      application_calendar_cronofy = application_calendar.client.create_cronofy(access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
      events = application_calendar_cronofy.read_events(params) rescue []
      events.each do |appointment|
        # puts appointment
        applcation_calendar_appointments << appointment
      end
    end
    applcation_calendar_appointments
  end

  def latest_start(new_start,duration,offset)
    case duration
      when 'days'
        new_start + (offset.to_i).days
      when 'weeks'
        new_start + (offset.to_i).weeks
      when 'months'
        new_start + (offset.to_i).months
      else
        new_start
    end
  end

  def send_email(email,reminder_text, reminder_subject, event_date_e, event_time_e, reply_to_email)
    if is_invalid_email(email)
      ClientNotifierMailer.generic_email(
            to: email,
            subject: reminder_subject % { event_date: event_date_e, event_time: event_time_e},
            body: reminder_text,
            reply_to_email: reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM']
          ).deliver_later
    end
  end

  def send_sms(cur_ivr,phone,content)
    msg_text = content
    if cur_ivr.confirmation_sms?
      if is_valid_mobile(phone)
        sms = create_sms(cur_ivr,phone,msg_text)
        telephony = telephony_create(telephony_name(cur_ivr))
        telephony.send_sms(sms.id) if sms.persisted?
      end
    end
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

  def telephony_name(cur_ivr)
    cur_ivr.preference['sms_engin'] || 'twilio'
  end

  def is_valid_mobile(phone_no)
    phone = Phonelib.parse(phone_no)
    (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile)) rescue false
  end

  def formatted_day(time,voice_locale)
    format = if I18n.exists?('time.formats.day', voice_locale)
               :day
             else
               :long
             end
    
    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def formatted_date(time,voice_locale)
    format = if I18n.exists?('time.formats.date', voice_locale)
               :date
             else
               :long
             end

    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def formatted_hour(time,voice_locale)
    format = if I18n.exists?('time.formats.hour', voice_locale)
               :hour
             else
               :long
             end

    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def create_sms(cur_ivr,phone,text)
    sms_text = text

    opts = {
        to: phone,
        content: sms_text,
        sms_type: 'single_sms',
        ivr: cur_ivr
    }
    TextMessage.create(opts)
  end
end