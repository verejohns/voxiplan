class WebhooksController < ApplicationController
  include ApplicationHelper

  require 'uri'
  skip_before_action :verify_authenticity_token

  before_action :authorize_webhook, only: :incoming_message

  # TODO: Delete rasa actions are managed on Python side
  # before_action :load_session, only: :rasa
  # def load_session
  #   request.session_options[:id] = params[:sender_id]
  # end
  #
  # # used as custom action for RASA
  # def rasa
  #   session[:data] ||= {} # initialize
  #   render json: RasaAction.perform(session[:data], params), status: :ok
  # end

  # POST /webhooks/voxi_sms
  # This endpoint will handle all payloads sent by VoxiSMS android app
  # Sample Payload
  # {:content=>"Test",
  #  :event=>"incoming_message",
  #  :from_number=>"+77079916518",
  #  :id=>"5f60f745-6c70-4f4b-ab4e-2eb4d77da9fd",
  #  :time_sent=>1565543991330,
  #  :customer_id=>"100500"}
  def sms_webhook
    if(params.has_key?(:From) && params.has_key?(:iid))
      twilio_sms_status
    elsif params.has_key?(:From)
      twilio_sms
    else
      voxi_sms
    end
    head :ok
  end

  def voxi_sms
    if params[:event] == 'incoming_message'
      handle_incoming_message
    else
      handle_status_changes
    end
    head :ok
  end

  # def perform
  #   begin
  #     # smsback = URI::encode("https://437f755e.ngrok.io/webhooks/twilio_sms_status?to=+9213456&from=+87497&iid=1")
  #     # reply = TextMessage.create(
  #     #   to: '+19292079050',
  #     #   content: 'Test Message',
  #     #   sms_type: 'ai_bot',
  #     #   ivr: Ivr.first,
  #     #   from: '+19292079050',
  #     #   statusCallback: "https://437f755e.ngrok.io/webhooks/twilio_sms_status?to=+9213456&from=+87497&iid=1"
  #     # )
  #     client = Twilio::REST::Client.new(ENV['ACCOUNT_SID'] ,ENV['AUTH_TOKEN'])

  #     # TextMessage.create(
  #     #   from: '+32460231111', to: '+32484605311', session_id: "voxi-", ivr: Client.first.ivrs.first,
  #     #   content: 'Test Message to check call back with single endpoint', time_sent: Time.now
  #     # )

  #     client.messages.create({
  #       to: '+32484605311',
  #       body: 'Test Message to check call back with single endpoint',
  #       from: '+32460231111',
  #       status_callback: 'https://abe6c6d2c377.ngrok.io/sms?iid=1'})

  #     # Conversation.create(
  #     #   client_id: Client.first.id, ivr_id: Client.first.ivrs.first.id, from: '+32460231111', to: '+32484605311'
  #     # )

  #     # debugger

  #     # TwilioSMSJob.perform_later(reply.id)
  #     return render :json => {}
  #   rescue Exception => e
  #     puts e.message
  #     puts e.backtrace
  #     return render :json => {}
  #   end
  # end

  def sms; end

  def timify_auth
      set_relative_data
      assign_webhook_access_data
    # response = json_to_hash params.keys.first
    # Timify.handle_access(response)
    # render :json => {}, status: 200
  end

  def cronofy
    cronofy_params = request.env['omniauth.params']
    cronofy_auth = request.env['omniauth.auth']
    cronofy_profile = cronofy_auth.extra.linking_profile
    agenda = AgendaApp.find_by(id: cronofy_params['agenda_app'])

    if agenda
      return_url = request.env['omniauth.origin'] + "&success=true&access_token=" + cronofy_auth.credentials.token + "&refresh_token=" + cronofy_auth.credentials.refresh_token +
        "&profile_id=" + cronofy_profile.profile_id + "&profile_name=" + cronofy_profile.profile_name + "&provider_name=" + cronofy_profile.provider_name +
        "&account_id=" + cronofy_auth.uid + "&agenda_id=" + cronofy_params['agenda_app']
    else
      return_url = request.env['omniauth.origin'] + "&success=false"
    end
    redirect_to return_url

  end

  def set_relative_data
    @data = {
      type: params[:type],
      companyId: params[:company_id],
      email: params[:email],
      accessToken: params[:access_token]
    }
  end

  def assign_webhook_access_data
    if WebhookCallDetail.find_by_email(@data[:email]).present?
      WebhookCallDetail.update(email: @data[:email], access_token: @data[:accessToken], auth_data: @data)
    else
      WebhookCallDetail.new(email: @data[:email], access_token: @data[:accessToken], auth_data: @data).save
    end
  end

  def tropo
    logger.info '*************** Tropo webhook recieved ********* '
    r = TropoWebhook.create_payload(params.permit!)

    logger.error "************** Could not persist Tropo webhook: #{r.errors.inspect} ************ " unless r.persisted?
    render json: {result: 'OK'}, status: 200
  end

  def recording
    puts "********** recording webhook received params #{params.inspect}"

    # call = Call.where('tropo_call_id like ?', "#{uploaded_io.original_filename.first(30)}%").take
    recording = Recording.find_by(uuid: params[:uuid])
    # find recording  and update its link
    render json: {result: 'OK'}, status: :accepted and return unless recording

    recording.update(
        url: params[:RecordingUrl],
        eid: params[:RecordingSid],
        duration: params[:RecordingDuration],
        status: params[:RecordingStatus],
        started_at: params[:RecordingStartTime],
    )
    # Remove code used with Tropo
    # uploaded_io = params[:filename]
    # File.open(Rails.root.join('public', 'uploads', uploaded_io.original_filename), 'wb') do |file|
    #   file.write(uploaded_io.read)
    # end
    # call = Call.where('tropo_call_id like ?', "#{uploaded_io.original_filename.first(30)}%").take
    # call.recording = uploaded_io
    # call.save

    render json: {result: 'OK'}, status: :created
  end

  def twilio_status_callback
    if params[:CallStatus] == "completed"
      called_number = params[:Called].include?('+') ? params[:Called][1..] : params[:Called]
      caller = params[:Caller].include?('+') ? params[:Caller][1..] : params[:Caller]
      identifier = Identifier.find_by_identifier(called_number)
      if identifier
        ivr = Ivr.find(identifier.ivr_id)
        organization = ivr.client.organizations.first

        if ivr.preference['only_ai'] && (organization.chargebee_subscription_plan == "premium" || organization.chargebee_subscription_plan == "trial" || organization.chargebee_subscription_plan == "custom")
          if Rails.cache.read("voxisession-#{ivr.id}-#{caller}")
            session_id = "voxi-#{Rails.cache.read("voxisession-#{ivr.id}-#{caller}")}"
          else
            voxi_session = VoxiSession.where(ivr_id: ivr.id, client_id: ivr.client.id, caller_id: caller).first
            if voxi_session
              session_id = "voxi-#{voxi_session.session_id}"
              Rails.cache.write("voxisession-#{ivr.id}-#{caller}", voxi_session.session_id)
            end
          end

          RasaParty.new(session_id, ivr.assistant_name, ivr.message_locale[0..1], ivr.preference['widget_tz'], "#{ivr.message_locale}-#{ivr.client.country_code}", "api").chat(message: '/end') if session_id
        end
      end
    end
  rescue => e
    puts e
  end

  def chargebee_event_handler
    event_type = params[:event_type]
    event_id = params[:id]
    puts "************************ event_type ***************************"
    puts event_type
    puts params
    if event_type == 'subscription_changed' || event_type == 'subscription_created' || event_type == 'subscription_activated' || event_type == 'subscription_cancelled' || event_type == 'subscription_reactivated'
      total_amount = params[:content].include?(:invoice) ? params[:content][:invoice][:sub_total] : 0
      subscription_id = params[:content][:subscription][:id]

      organization = Organization.find_by(chargebee_subscription_id: subscription_id)
      client = Client.find(organization.client_id) if organization

      item_price_id = params[:content][:subscription][:subscription_items][0][:item_price_id]
      membership = 'trial' if item_price_id == ENV['PREMIUM_TRIAL_USD_ID'] || item_price_id == ENV['PREMIUM_TRIAL_EUR_ID']
      membership = 'free' if item_price_id == ENV['FREE_MONTHLY_USD_ID'] || item_price_id == ENV['FREE_MONTHLY_EUR_ID']
      membership = 'basic' if item_price_id == ENV['BASIC_MONTHLY_USD_ID'] || item_price_id == ENV['BASIC_YEARLY_USD_ID'] || item_price_id == ENV['BASIC_MONTHLY_EUR_ID'] || item_price_id == ENV['BASIC_YEARLY_EUR_ID']
      membership = 'premium' if item_price_id == ENV['PREMIUM_MONTHLY_USD_ID'] || item_price_id == ENV['PREMIUM_YEARLY_USD_ID'] || item_price_id == ENV['PREMIUM_MONTHLY_EUR_ID'] || item_price_id == ENV['PREMIUM_YEARLY_EUR_ID']
      membership = 'custom' if item_price_id == ENV['CUSTOM_MONTHLY_USD_ID'] || item_price_id == ENV['CUSTOM_YEARLY_USD_ID'] || item_price_id == ENV['CUSTOM_MONTHLY_EUR_ID'] || item_price_id == ENV['CUSTOM_YEARLY_EUR_ID']

      membership_period = 'monthly' if item_price_id == ENV['BASIC_MONTHLY_USD_ID'] || item_price_id == ENV['PREMIUM_MONTHLY_USD_ID'] || item_price_id == ENV['CUSTOM_MONTHLY_USD_ID'] || item_price_id == ENV['BASIC_MONTHLY_EUR_ID'] || item_price_id == ENV['PREMIUM_MONTHLY_EUR_ID'] || item_price_id == ENV['CUSTOM_MONTHLY_EUR_ID']
      membership_period = 'yearly' if item_price_id == ENV['BASIC_YEARLY_USD_ID'] || item_price_id == ENV['PREMIUM_YEARLY_USD_ID'] || item_price_id == ENV['CUSTOM_YEARLY_USD_ID'] || item_price_id ==  ENV['BASIC_YEARLY_EUR_ID'] || item_price_id == ENV['PREMIUM_YEARLY_EUR_ID'] || item_price_id == ENV['CUSTOM_YEARLY_EUR_ID']
      membership_period = 'monthly' if membership == 'free'
      puts "************************ content subscription ***************************"
      puts params[:content][:subscription]
      seat_nums = params[:content][:subscription][:subscription_items][0][:quantity]

      puts "********************** seat_nums ******************************"
      puts seat_nums
      puts organization.inspect
      if client && organization && seat_nums < organization.chargebee_seats
        client.ivrs.each do |ivr|
          ivr.resources.where(client_id: client.id, enabled: true).order(id: :asc).each_with_index do |resource, index|
            puts "********************** every resource ******************************"
            puts resource.id
            puts index
            puts seat_nums

            next if index < seat_nums

            puts "********************** disable resource ******************************"
            puts resource.id

            resource.update_columns(enabled: false)
            ResourceService.where(resource_id: resource.id).destroy_all

            e_resource = Resource.find_by_eid(resource.id)
            if e_resource
              e_resource.update_columns(enabled: false)
              ResourceService.where(resource_id: e_resource.id).destroy_all
            end
          end
        end
      end

      if client && organization
        if event_type == 'subscription_activated' && membership = 'trial'
          ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
          result = ChargeBee::Subscription.update_for_items(params[:content][:subscription][:id],{
            :invoice_immediately => false,
            :subscription_items => [{
                                      :item_price_id => ENV["FREE_MONTHLY_#{client.currency_code}_ID"]
                                    }]
          })
          puts "*********** change_plan_to_free ****************"
          puts result
          membership = 'free'
        end

        subscriptions = client.subscription.where(subscription_id: subscription_id, event_id: event_id)

        membership = 'trial' if event_type == 'subscription_created' && organization.chargebee_subscription_plan == "trial"
        if event_type == 'subscription_cancelled'
          membership = 'free'
          membership_period = 'monthly'
        end

        if subscriptions.count.zero?
          chargebee_seats = 1 if membership == 'free' || membership == 'trial'
          chargebee_seats = seat_nums if membership == 'basic' || membership == 'premium' || membership == 'custom'
          chargebee_subscription_period = membership_period

          current_plan = organization.chargebee_subscription_plan

          unless current_plan == membership
            deleteRelationTupleSet("/app", current_plan, "/organization-" + organization.id.to_s, "owner")
            deleteRelationTupleSet("/app", current_plan, "/organization-" + organization.id.to_s, "member")

            addRelationTupleSet("/app", membership, "/organization-" + organization.id.to_s, "owner")
            addRelationTupleSet("/app", membership, "/organization-" + organization.id.to_s, "member")
          end
          puts "************** chargebee_seats ***************"
          puts chargebee_seats
          organization.update_columns(chargebee_seats: chargebee_seats, chargebee_subscription_period: chargebee_subscription_period, chargebee_subscription_plan: membership)

          subscription = client.subscription.new(subscription_id: subscription_id, event_id: event_id, membership: membership, period: membership_period, seats: seat_nums, amount: total_amount)
          subscription.save

          if membership == 'free'
            client.ivrs.each do |ivr|
              # every resource except default resource will be disabled
              ivr.resources.where("is_default=false").update_all(enabled: false)

              # disconnect every agenda
              ivr.client.agenda_apps.each do |agenda|
                if agenda.type == 'ClassicAgenda'
                  agenda.close_channel(agenda.channel_id)
                  data_center = client.data_server
                  query = {
                    'client_id'     => ENV["CRONOFY_#{data_center}_CLIENT_ID"],
                    'client_secret' => ENV["CRONOFY_#{data_center}_CLIENT_SECRET"],
                    'token'         => agenda.cronofy_refresh_token
                  }
                  headers = {
                    'Content-Type'  => 'application/json',
                  }

                  HTTParty.post(
                    helpers.get_api_center_url(data_center) + "/oauth/token/revoke",
                    :query => query,
                    :headers => headers
                  )
                end

                ivr.resources.where(calendar_id: agenda.calendar_id).update_all(calendar_id: nil)
                agenda.destroy
              end

              active_services = ivr.services.active.order(id: :asc)
              active_services.each_with_index do |service, index|
                resource_dependencies = ResourceService.where(service_id: service.id).order(id: :asc)
                resource_dependencies.each_with_index do |dependency, idx|
                  next if idx.zero?

                  Resource.find(dependency.resource_id).update_columns(enabled: false) if ResourceService.where("service_id != ? and resource_id = ?", service.id, dependency.resource_id).count.zero?
                  Resource.where(eid: dependency.resource_id).update_all(enabled: false) if ResourceService.where("service_id != ? and resource_id = ?", Service.where(eid: service.id).first.id, Resource.where(eid: dependency.resource_id).first.id).count.zero?
                  dependency.destroy
                  ResourceService.where(service_id: Service.where(eid: service.id).first.id).delete_all
                end

                if index.zero?
                # if service.is_default
                  service.enabled = true
                  service.preference["widget_enabled"] = true
                  Service.where(eid: service.id).update_all(enabled: true)
                else
                  service.enabled = false
                  service.preference["widget_enabled"] = false
                  service.preference["phone_assistant_enabled"] = false
                  service.preference["chat_enabled"] = false
                  service.preference["sms_enabled"] = false
                  service.preference["ai_phone_assistant_enabled"] = false
                  Service.where(eid: service.id).update_all(enabled: false)
                end

                service.save
              end
            end

            # disconnect every application calendar except owner's in organization
            application_calendars = ApplicationCalendar.where(organization_id: organization.id, client_id: !client.id)
            application_calendars.each do |application_calendar|
              data_center = client.data_server
              query = {
                'client_id'     => ENV["CRONOFY_#{data_center}_CLIENT_ID"],
                'client_secret' => ENV["CRONOFY_#{data_center}_CLIENT_SECRET"],
                'token'         => application_calendar.refresh_token
              }
              headers = {
                'Content-Type'  => 'application/json',
              }

              HTTParty.post(
                helpers.get_api_center_url(data_center) + "/oauth/token/revoke",
                :query => query,
                :headers => headers
              )

              client.resources.where(calendar_id: application_calendar.calendar_id).update_all(calendar_id: nil)
              application_calendar.destroy
            end

            default_application_calendar = ApplicationCalendar.where(organization_id: organization.id, client_id: client.id).first
            client.resources.update_all(conflict_calendars: default_application_calendar.conflict_calendars, calendar_id: default_application_calendar.calendar_id)
          else
            if chargebee_seats < client.resources.active.count
              client.resources.active.order('created_at').each_with_index do |resource, index|
                puts "********** active_resources ****************"
                puts resource.inspect
                if (index + 1) > chargebee_seats
                  resource.update_columns(enabled: false)
                  ResourceService.where(resource_id: resource.id).destroy_all
                  ResourceService.where(resource_id: Resource.find_by_eid(resource.id).id).destroy_all
                end
              end
            end
          end

          client.ivrs.each do |ivr|
            if membership != 'premium' && membership != 'custom'
              ivr.remove_voxiplan_branding = false
              ivr.save
            end
            ivr.services.each_with_index do |service, index|
              if membership != 'premium' && membership != 'custom'
                if membership == "free"
                  unless index.zero?
                    service.enabled = false
                    service.preference["enabled"] = false
                    service.preference["widget_enabled"] = false
                  end

                  service.preference["phone_assistant_enabled"] = false
                end

                service.preference["chat_enabled"] = false
                service.preference["sms_enabled"] = false
                service.preference["ai_phone_assistant_enabled"] = false

                service.save
              end
            end
          end

        end
      end
    end
  rescue => e
    puts e
  end

  def cronofy_event_trigger
    if params[:event] && params[:notification]
      notification = params[:notification]
      notification_type = notification[:type]
      notification_transitions = notification[:transitions]
      if notification_type == "event_subscription" && notification_transitions[0][:type] == "event_start"
        event = params[:event]
        event_id = event[:event_id]
        event_summary = event[:summary]
        event_start = event[:start]
        appointment = Appointment.find_by(event_id: event_id)
        if appointment
          resource = appointment.resource

          reminder = appointment.service_id.nil? ? nil : Reminder.where(client_id: appointment.client_id, service_id: appointment.service_id).first
          if reminder.nil?
            reminder_text = t('mails.default_reminder.reminder_text')
            reminder_text_host = t('mails.default_reminder.reminder_text_host')
            reminder_email_subject = t('mails.default_reminder.reminder_email_subject')
            reminder_email_subject_host = t('mails.default_reminder.reminder_email_subject_host')
            reminder_sms_text = t('mails.default_reminder.reminder_sms_text')

          else
            reminder_text = reminder.text
            reminder_text_host = reminder.text_host
            reminder_email_subject = reminder.email_subject
            reminder_email_subject_host = reminder.email_subject_host
            reminder_sms_text = reminder.sms_text
          end

          client = appointment.client
          ivr = appointment.ivr
          customer = appointment.caller_id.nil? ? nil : Customer.find(appointment.caller_id&.to_i)

          event_day = formatted_day(event_start.to_time.in_time_zone(client.time_zone), ivr.voice_locale)
          event_date = formatted_date(event_start.to_time.in_time_zone(client.time_zone), ivr.voice_locale)
          event_time = formatted_hour(event_start.to_time.in_time_zone(client.time_zone), ivr.voice_locale)
          customer_first_name = customer.nil? ? ivr.client.first_name : customer&.first_name
          customer_last_name = customer.nil? ? ivr.client.last_name : customer&.last_name
          customer_full_name = customer.nil? ? ivr.client.full_name : customer&.full_name
          replace_options = {event_name: event_summary, event_day: event_day, event_date: event_date, event_time: event_time,
                 first_name: customer_first_name, last_name: customer_last_name, full_name: customer_full_name, resource_name: resource.name}
          reminder_text = reminder_text % replace_options
          reminder_subject = reminder_email_subject % replace_options


          if reminder.nil? || reminder.email
            reminder_text_host = reminder_text_host % replace_options
            reminder_subject_host = reminder_email_subject_host % replace_options

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

          reg = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i
          reg1 = /\d+/
          cancel_link = reminder.nil? ? '' : reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: event_id, type: 'cancel') : ''
          reschedule_link = reminder.nil? ? '' : reminder.is_include_cancel_link ? appointment_widget_url(ivr.booking_url, event_id: event_id, type: 'schedule') : ''
          template_data_invitee = {
            title: t("mails.client_appointment_confirmed.title"),
            body: reminder_text,
            subject: reminder_subject || 'Reminder',
            cancel_link: cancel_link,
            reschedule_link: reschedule_link,
            copyright: t("mails.copyright"),
            reply_to_or_contact_us: t("mails.reply_to_or_contact_us")
          }

          event[:description].scan(reg).uniq.each do |email|
            # send_email(email, reminder_text, reminder.email_subject || 'Reminder', formatted_date(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), formatted_hour(agenda_appointment.start.to_time.in_time_zone(ivr.client.time_zone),ivr.voice_locale), ivr.client.email)
            options = { to: email, template_id: ENV['VOXIPLAN_CONTACT_APPOINTMENT'], template_data: template_data_invitee, reply_to_email: ivr.client.email, reply_to_name: ivr.client.full_name }
            SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
          end

          sms_text = reminder_sms_text % replace_options
          if reminder.nil? || reminder.sms
            (event_summary + ' ' + event[:description]).scan(reg1).uniq.each do |phone|
              send_sms(ivr, phone, sms_text) if phone.length >= 10
            end
          end

        end

        return render json: {}, status: 202
      end
    end
  rescue => e
    puts e.message
  end

  private

  def send_sms(cur_ivr, phone, content)
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

  def create_sms(cur_ivr,phone,text)
    sms_text = text
    opts = { to: phone, content: sms_text, sms_type: 'single_sms', ivr: cur_ivr }
    TextMessage.create(opts)
  end

  def formatted_day(time,voice_locale)
    format = I18n.exists?('time.formats.day', voice_locale) ? :day : :long
    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def formatted_date(time,voice_locale)
    format = I18n.exists?('time.formats.date', voice_locale) ? :date : :long
    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def formatted_hour(time,voice_locale)
    format = I18n.exists?('time.formats.hour', voice_locale) ? :hour : :long
    I18n.l(time, format: format, locale: voice_locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month)) rescue I18n.l(time, format: format, locale: voice_locale[0..1], day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def authorize_webhook
    return if params[:secret_key] && params[:secret_key] == ENV['VOXIPLAN_SECRET_KEY']
    render json: { result: 'Invalid secret key' }, status: :unauthorized
  end

  def handle_incoming_message
    ivr = Ivr.find_by("preference->> 'voxi_sms_customer_id' = ? ", params[:customer_id])
    return unless ivr

    return unless Phonelib.parse(params[:from_number]).valid?

    session[:data] = ivr.session_variables(phone: params[:from_number], platform: 'sms')

    voxi_session = VoxiSession.find(session[:data][:current_voxi_session_id])
    voxi_session.update_columns(session_id: session.id.to_s)

    TextMessage.create(
      from: params[:from_number], to: ivr.sms_number, session_id: "voxi-#{session.id}", ivr: ivr,
      content: params[:content], incoming: true, time_sent: time(params[:time_sent])
    )
  rescue => e
    puts e.message
  end

  def handle_status_changes
    msg = TextMessage.find_by(uuid: params[:id])
    return unless msg
    msg.status = params[:status]
    msg.time_sent = time(params[:time]) if params[:status] == '-1' # sms sent
    msg.save
  end

  def twilio_sms_status

    return unless params[:iid]
    ivr = Ivr.find(params[:iid])
    return unless ivr

    msg = ivr.text_messages.where(from: params[:From],to: params[:To],created_at: Range.new(Time.now.utc - 2.hours, Time.now.utc)).first

    return unless msg

    msg.twilio_status = params[:MessageStatus]
    msg.save!

    head :ok
  end

  def twilio_sms
    begin
      ivr_id = Identifier.find_by_identifier(PhoneNumber.find_by_number(params[:To]).try(:number).gsub('+', '')).try(:ivr_id)
    rescue Exception => e
      puts e.message
    end
    begin
      ivr_id = Conversation.where(from: params[:To], to: params[:From], created_at: Range.new(1.day.ago, Time.now.utc)).first.try(:ivr_id) if ivr_id.blank?
    rescue Exception => e
      puts e.message
    end
    ivr = Ivr.find(ivr_id) if ivr_id
    # ivr = Ivr.find(Identifier.find_by_identifier(params[:To].tr('+, ', '')).try(:ivr_id))
    return unless ivr

    return unless Phonelib.parse(params[:From]).valid?

    session[:data] = ivr.session_variables(phone: params[:From], platform: 'sms')

    TextMessage.create(
      from: params[:From], to: params[:To], session_id: "voxi-#{session.id}", ivr: ivr,
      content: params[:Body], incoming: true, time_sent: Time.now
    )
    head :ok
  end

  def time(unix_js_time)
    Time.at(unix_js_time.to_i / 1000)
  end


end
