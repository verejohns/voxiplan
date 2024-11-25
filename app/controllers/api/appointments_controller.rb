module Api
  class AppointmentsController < Api::BaseController
    # return existing appointments
    def index
      begin
        c_id = (agenda_app.ivr.resources.pluck(:calendar_id) << agenda_app.default_resource_calendar).uniq.compact
      rescue Exception => e
        puts e
        c_id = nil
      end

      params = {agenda_customer_id: current_customer ? current_customer.eid : nil }
      params.merge!(calendar_ids: c_id) if c_id || (agenda_app.count > 0 && agenda_app.first.type == 'ClassicAgenda')

      appointments = client_agenda.existing_appointments(params)
      appointments = appointments.map{|s| s.merge('id' => store_existing_appointment(s) ) }
      appointments.each do |appointment|
        service = Service.where(ivr_id: session[:data][:current_ivr_id], eid: appointment["service"]).first
        resource = Resource.where(ivr_id: session[:data][:current_ivr_id], eid: appointment["resource"]).first
        if service
          if service.client_id
            appointment["service"] = service.id.to_s
          else
            appointment["service"] = Service.find(service.eid).id.to_s
          end
        end

        if resource
          if resource.client_id
            appointment["resource"] = resource.id.to_s
          else
            appointment["resource"] = Resource.find(resource.eid).id.to_s
          end
        end
      end

      render json: appointments
    end

    def create
      raise "Doesn't exist slot ID" unless params[:slot_id].present?

      attr = create_appointment(params[:slot_id])

      return render json: {result: 'failure', message: 'Invalid slot'} if attr[:start].nil?

      created = client_agenda.create_appointment(attr.except(:identifier))

      Appointment.create(caller_id: current_customer ? current_customer.id : nil, caller_name: current_customer ? current_customer.full_name : '',
       time: Time.at(Time.parse(params[:slot_id])), tropo_session_id: nil, client_id: current_ivr.client.id, source: 'API', ivr_id: current_ivr.id,
       resource_id: attr[:resource], service_id: attr[:service], event_id: created[:event][:event_id], status: 'Confirmed') if created || created[:result]
      session[:data][:event_id_cronofy] = nil

      client = current_ivr.client
      resource = Resource.where(id: attr[:resource]).first || Resource.where(eid: attr[:resource], client_id: client.id).first
      service = Service.where(id: attr[:service]).first || Service.where(eid: attr[:service], client_id: client.id).first
      customer = current_customer

      email_invitee = client.service_notifications.where(service_id: service.id, automation_type: "confirmation_email_invitee")
      if email_invitee.count.zero?
        email_invitee_subject = I18n.t("mails.confirmation_email_invitee.subject").html_safe
        email_invitee_body = I18n.t("mails.confirmation_email_invitee.body").html_safe
        invitee_include_cancel_link = true
      else
        email_invitee_subject = email_invitee.first.subject
        email_invitee_body = email_invitee.first.text
        invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
      end

      email_host = client.service_notifications.where(service_id: service.id, automation_type: "confirmation_email_host")
      if email_host.count.zero?
        use_email_host = false
        email_host_subject = I18n.t("mails.confirmation_email_host.subject").html_safe
        email_host_body = I18n.t("mails.confirmation_email_host.body").html_safe
      else
        email_host_subject = email_host.first.subject
        email_host_body = email_host.first.text
        use_email_host = email_host.first.use_email_host
      end

      event_date_time = Time.parse(params[:slot_id]).in_time_zone(current_ivr.client.time_zone)

      cancel_link = invitee_include_cancel_link ? appointment_widget_url(current_ivr.booking_url, event_id: created[:event][:event_id], type: 'cancel') : ''
      reschedule_link = invitee_include_cancel_link ? appointment_widget_url(current_ivr.booking_url, event_id: created[:event][:event_id], type: 'schedule') : ''

      if use_email_host && customer
        email_body = email_host_body % {full_name: customer.full_name,
                                        first_name: customer.first_name,
                                        last_name: customer.last_name,
                                        resource_name: resource&.name,
                                        event_name: service&.name,
                                        event_date: I18n.l(event_date_time.to_date, format: :long, locale: current_ivr.voice_locale),
                                        event_time: event_date_time.strftime("%I:%M %p"),
                                        event_day: event_date_time.strftime("%A")}

        template_data_client = {
          title: I18n.t("mails.client_appointment_confirmed.title"),
          body: email_body,
          subject: email_host_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }

        options = { to: current_ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

        resource_user_email(resource, email_body, email_host_subject)
      end

      if customer && customer.email.present?
        email_body = email_invitee_body % {full_name: customer.full_name,
                                           first_name: customer.first_name,
                                           last_name: customer.last_name,
                                           resource_name: resource&.name,
                                           event_name: service&.name,
                                           event_date: I18n.l(event_date_time.to_date, format: :long, locale: current_ivr.voice_locale),
                                           event_time: event_date_time.strftime("%I:%M %p"),
                                           event_day: event_date_time.strftime("%A")}

        template_data_invitee = {
          title: I18n.t("mails.client_appointment_confirmed.title"),
          body: email_body,
          subject: email_invitee_subject,
          cancel_link: cancel_link,
          reschedule_link: reschedule_link,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }

        options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: current_ivr.client.email, reply_to_name: current_ivr.client.full_name }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end

      render json: {result: created[:result] ? 'success' : 'failure'}
    end

    def create_appointment(slot_id)
      attr = {}
      attr.merge! common_required_attributes
      attr[:id] = 0

      attr[:service] = Appointment.find_by_event_id(data[:choosen_existing_appointment_id]).service_id.to_s if attr[:service] == ""

      free_slots = client_agenda.free_slots(nil, Time.current,{service_id: attr[:service] || data[:choosen_service], resource_id: attr[:resource] || data[:choosen_resource]})
      puts "***********8 free_slots **************"
      puts attr
      puts data
      puts free_slots
      puts free_slots[0]["start"].utc
      puts Time.parse(slot_id).utc
      free_slots.each do |slot|
        if slot["start"].utc == Time.parse(slot_id).utc
          attr[:start] = slot["start"].utc
          attr[:end] = slot["finish"].utc
          if client_agenda.type == 'Mobminder'
            attr[:bCals] = slot["bCals"]
            attr[:cueIn] = slot["sid"]["cueIn"]
            attr[:cueOut] = slot["sid"]["cueOut"]
            attr[:workcodes] = slot["sid"]["workcodes"]
          elsif client_agenda.type == 'Timify'
            attr[:service_id] = slot["sid"]["service_id"]
            attr[:resource_id] = slot["sid"]["resource_id"]
            attr[:datetime] = slot["sid"]["datetime"]
            attr[:duration] = slot["sid"]["duration"]
          end
        end
      end

      attr
    end

    def resource_user_email(resource, email_body, email_host_subject)
      if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
        team_client = Client.find(resource.team_calendar_client_id)
        if team_client
          template_data_team_client = {
            title: I18n.t("mails.client_appointment_confirmed.title"),
            body: email_body,
            subject: email_host_subject,
            copyright: I18n.t("mails.copyright"),
            reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
          }

          options = { to: team_client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_team_client }
          SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
        end
      end
    end

    def send_reschedule_email(event_id, new_slot)
      appointment = Appointment.where(event_id: event_id)
      resource = Resource.where(id: appointment&.first&.resource_id).first || Resource.where(eid: appointment&.first&.resource_id, client_id: current_ivr.client.id).first
      service = Service.where(id: appointment&.first&.service_id).first || Service.where(eid: appointment&.first&.service_id, client_id: current_ivr.client.id).first
      client = Client.find(current_ivr.client_id)
      customer = current_customer

      email_invitee = client.service_notifications.where(service_id: service.id, automation_type: "rescheduling_email_invitee")
      if email_invitee.count.zero?
        email_invitee_subject = I18n.t("mails.rescheduling_email_invitee.subject").html_safe
        email_invitee_body = I18n.t("mails.rescheduling_email_invitee.body").html_safe
        invitee_include_cancel_link = true
      else
        email_invitee_subject = email_invitee.first.subject
        email_invitee_body = email_invitee.first.text
        invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
      end

      email_host = client.service_notifications.where(service_id: service.id, automation_type: "rescheduling_email_host")
      if email_host.count.zero?
        use_email_host = false
        email_host_subject = I18n.t("mails.rescheduling_email_host.subject").html_safe
        email_host_body = I18n.t("mails.rescheduling_email_host.body").html_safe
      else
        email_host_subject = email_host.first.subject
        email_host_body = email_host.first.text
        use_email_host = email_host.first.use_email_host
      end

      st_time = Time.at(Time.parse(new_slot)).in_time_zone('UTC')
      cancel_link = invitee_include_cancel_link ? appointment_widget_url(current_ivr.booking_url, event_id: event_id, type: 'cancel') : ''
      reschedule_link = invitee_include_cancel_link ? appointment_widget_url(current_ivr.booking_url, event_id: event_id, type: 'schedule') : ''
      event_date_time = st_time.in_time_zone(current_ivr.client.time_zone)

      if use_email_host && customer
        email_body = email_host_body % {full_name: customer.full_name,
                                        first_name: customer.first_name,
                                        last_name: customer.last_name,
                                        resource_name: resource&.name,
                                        event_name: service&.name,
                                        event_date: I18n.l(event_date_time.to_date, format: :long, locale: current_ivr.voice_locale),
                                        event_time: event_date_time.strftime("%I:%M %p"),
                                        event_day: event_date_time.strftime("%A")}

        template_data_client = {
          title: I18n.t("mails.confirmation.body_line8"),
          body: email_body,
          subject: email_host_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }

        options = { to: current_ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_APPOINTMENT'], template_data: template_data_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

        resource_user_email(resource, email_body, email_host_subject)
      end

      if customer && customer.email.present?
        email_body = email_invitee_body % {full_name: customer.full_name,
                                           first_name: customer.first_name,
                                           last_name: customer.last_name,
                                           resource_name: resource&.name,
                                           event_name: service&.name,
                                           event_date: I18n.l(event_date_time.to_date, format: :long, locale: current_ivr.voice_locale),
                                           event_time: event_date_time.strftime("%I:%M %p"),
                                           event_day: event_date_time.strftime("%A")}

        template_data_invitee = {
          title: I18n.t("mails.confirmation.body_line8"),
          body: email_body,
          subject: email_invitee_subject,
          cancel_link: cancel_link,
          reschedule_link: reschedule_link,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }

        options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: current_ivr.client.email, reply_to_name: current_ivr.client.full_name }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end
    end

    def update
      # No longer required. We can directly use make appointment call
      # To update we need to pass id of existing appointment that we are
      # setting in availability call along with selected resource/service

      appointments = getAppointments()

      appointments.each do |appointment|
        if appointment["tid"] == params[:slot_id]
          data[:choosen_existing_appointment_id] = appointment['id']
          data[:choosen_resource] = appointment['resource']
          data[:choosen_service] = appointment['service']

          attr = create_appointment(params[:new_id])

          return render json: {result: 'failure', message: 'Invalid slot'} if attr[:start].nil?

          attr[:evt_id] = appointment["id"]
          attr[:id] = appointment["id"]

          created = client_agenda.create_appointment(attr.except(:identifier))

          re_appointment = Appointment.find_by_event_id(attr[:evt_id])
          if re_appointment
            rescheduled_count = re_appointment.rescheduled_count ? re_appointment.rescheduled_count + 1 : 1
            re_appointment.update_attributes(time: Time.at(attr[:start]), event_id: created[:event][:event_id], status: "Rescheduled", rescheduled_count: rescheduled_count)
            send_reschedule_email(created[:event][:event_id], params[:new_id])
          end

          return render json: {result: created[:result]}
        end
      end

      raise 'Invalid ID'
    end

    def getAppointments
      begin
        c_id = (agenda_app.ivr.resources.pluck(:calendar_id) << agenda_app.default_resource_calendar).uniq.compact
      rescue Exception => e
        puts e
        c_id = nil
      end

      params = {agenda_customer_id: current_customer ? current_customer.eid : nil }
      params.merge!(calendar_ids: c_id) if c_id || (agenda_app.count > 0 && agenda_app.first.type == 'ClassicAgenda')

      appointments = client_agenda.existing_appointments(params)
      appointments.map{|s| s.merge('tid' => store_existing_appointment(s) ) }
    end

    def send_cancel_email(event_id)
      appointment = Appointment.where(event_id: event_id)
      event_date_time = appointment&.first&.time.in_time_zone(current_ivr.client.time_zone)
      event_name = appointment&.first&.service ? appointment&.first&.service.name : current_ivr.services.find_by_eid(appointment&.first&.service_id)
      event_date = I18n.localize(event_date_time.to_date, format: :long, locale: current_ivr.voice_locale)
      event_time = event_date_time.strftime("%I:%M %p")
      event_day = event_date_time.strftime("%A")
      customer = Customer.find(appointment&.first&.caller_id&.to_i)
      resource = Resource.where(id: appointment&.first&.resource_id).first || Resource.where(eid: appointment&.first&.resource_id, client_id: current_ivr.client.id).first
      service = Service.where(id: appointment&.first&.service_id).first || Service.where(eid: appointment&.first&.service_id, client_id: current_ivr.client.id).first

      email_invitee_notification = ServiceNotification.where(service_id: service.id, automation_type: 'cancellation_email_invitee')
      email_invitee_subject = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.subject') : email_invitee_notification.first.subject
      email_invitee_body = email_invitee_notification.count.zero? ? I18n.t('mails.cancellation_email_invitee.body') : email_invitee_notification.first.text
      email_invitee_body = email_invitee_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                 first_name: customer ? customer.first_name : '', last_name: customer ? customer.last_name : '', full_name: customer ? customer.full_name : '', resource_name: resource.name}
      # email_invitee_body = email_invitee_body + "<br>" + t('appointment_widget.reason') + params[:reason]

      email_host_notification = ServiceNotification.where(service_id: service.id, automation_type: 'cancellation_email_host')
      email_host_subject = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.subject') : email_host_notification.first.subject
      email_host_body = email_host_notification.count.zero? ? I18n.t('mails.cancellation_email_host.body') : email_host_notification.first.text
      email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                           first_name: customer ? customer.first_name : '', last_name: customer ? customer.last_name : '', full_name: customer ? customer.full_name : '', resource_name: resource.name}
      # email_host_body = email_host_body + "<br>" + I18n.t('appointment_widget.reason') + params[:reason]
      use_email_host = email_host_notification.count.zero? ? false : email_host_notification.first.use_email_host

      if use_email_host && customer
        template_data_client = {
          title: I18n.t("mails.cancellation_email_invitee.title"),
          body: email_host_body,
          subject: email_host_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }
        options = { to: current_ivr.client.email, template_id: ENV['VOXIPLAN_CLIENT_CANCEL'], template_data: template_data_client }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)

        if resource.calendar_type == "team_calendar" and resource.team_calendar_client_id and resource.team_calendar_client_id != ""
          team_client = Client.find(resource.team_calendar_client_id)
          if team_client
            team_client_email_host_body = email_host_body % {event_name: event_name, event_day: event_day, event_date: event_date, event_time: event_time,
                                                             first_name: customer.first_name, last_name: customer.last_name, full_name: customer.full_name, resource_name: resource.name}
            # team_client_email_host_body = team_client_email_host_body + "<br>" + t('appointment_widget.reason') + params[:reason]

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

      if customer && customer.email.present?
        template_data_invitee = {
          title: I18n.t("mails.cancellation_email_invitee.title"),
          body: email_invitee_body,
          subject: email_invitee_subject,
          copyright: I18n.t("mails.copyright"),
          reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
        }
        options = { to: customer.email, template_id: ENV['VOXIPLAN_CONTACT_CANCEL'], template_data: template_data_invitee, reply_to_email: current_ivr.client.email, reply_to_name: current_ivr.client.full_name }
        SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
      end
    end

    def destroy
      appointments = getAppointments()

      appointments.each do |appointment|
        if appointment["tid"] == params[:id]
          result = client_agenda.delete_appointment(appointment['id'])
          appointment_old = Appointment.find_by_event_id(appointment['id'])
          if appointment_old
            appointment_old.update_columns(status: "Cancelled")

            send_cancel_email(appointment['id'])
          end
          return render json: {result: result ? 'success' : 'failure'}
        end
      end

      raise 'Invalid ID'
    end

    private

    def store_existing_appointment(attr)
      id = attr['time'].iso8601 # SecureRandom.hex
      session[:data][:existing_appointments][id] = attr
      id
    end

    def data
      session[:data]
    end

    def current_customer
      Customer.find_by(id: data[:current_customer_id])
    end

    def common_required_attributes
      attrs = { caller_id: data[:caller_id],
                existing_appointment_id: data[:choosen_existing_appointment_id],
                resource: data[:choosen_resource], service: data[:choosen_service] }
      attrs[:customer_id] = current_customer.id if current_customer
      attrs[:agenda_customer_id] = current_customer.eid if current_customer
      client_agenda.common_required_attrs(attrs)
    end

    def dummy_agenda
      dummy_agenda = DummyAgenda::new
      dummy_agenda.ivr_id = current_ivr.id
      dummy_agenda.client_id = current_ivr.client.id
      dummy_agenda
    end

    def client_agenda
      agenda = agenda_app.count.zero? ? dummy_agenda : agenda_app.where('calendar_id IS NOT NULL').first
      agenda = agenda_app[0] if agenda.nil?
      agenda
    end
  end
end