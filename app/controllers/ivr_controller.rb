class IvrController < ApplicationController
  include PhoneNumberUtils
  skip_before_action :verify_authenticity_token

  # TODO: Remove this later
  # before_action :initial_call_setup, only: :welcome

  # set session if start_node
  # initial_call_setup is called from ApplicationController#set_time_zone
  # before_action :initial_call_setup, if: Proc.new{params[:id].nil?}, only: [:run]

  before_action :set_node, only: :run
  def set_node
    set_node_options
    if params[:id].present?
      @node = Node.find (params[:id])
    else
      # @node = Node.find_by(name: 'say1')
      @node = ivr.only_ai? ? ivr.ai_start_node : ivr.start_node
      # @node = Node.find 19
    end

  rescue Exception => e
    logger.error "***************** Exception while setting a node ************** "
    logger.error e.message
    logger.error e.backtrace.to_yaml
    @node = nil
  end

  def set_node_options
    @options = {}
    @options[:session_data] = session[:data]
    @options[:parse_response] = true if params[:parse_response].present?
    set_test_options if params[:test_input] || params[:cid] # for testing
    # @options[:tropo_session] = tropo_session if tropo?
    # # TODO: Rename and filter params
    @options[:tropo_session] = params if twilio?
  end

  def set_test_options
    @options[:test_input] = params[:test_input]
    @options[:session_data][:caller_id] ||= params[:uid] || params[:cid] || 'test'
  end

  def run
    # next_node = @node.run
    # redirect_to run_node_path(next_node) and return if next_node
    session[:data][:session_id] = "voxi-#{session.id}"
    response = @node ? @node.run(@options) : reject

    if params[:cid] && params[:web]
      @resp = response.to_xml
      render 'layouts/ivr_test', layout: false and return
    end

    render xml: response, status: 200 and return
    # render plain: 'Success!'
  end

  def welcome
    tropo.say client.welcome
    tropo.on :event => 'continue', :next => '/menu1.json'

    render json: tropo.response, status: 200
  end

  def menu1
    tropo.on :event => 'continue', :next => '/handle_menu1.json'
    tropo.ask({
                  name: 'menu1',
                  say: [{
                            value: client.incorrect_option,
                            event: 'nomatch'
                        },
                        {
                            value: client.menu1
                        }],
                  choices: {
                      value: '1, 2',
                      mode: 'dtmf'
                  },
                  timeout: 5.0,
                  attempts: 3,
                  required: 'true',
                  bargein: 'true',
              }
    )

    render json: tropo.response, status: 200
  end


  def handle_menu1
    answer = tropo_response[:result][:actions][:menu1][:value]

    case answer
      when '1'
        menu2
      when '2'
        # In case of emergency
        forward_to_agent
      else
        handle_incorrect
    end
  end

  # first appointment
  def menu2
    get_first_free_slot

    # message = "The doctor told me to offer you the next possible appointment on #{formatted_time(slot1[:start])}"
    # message += "Press 1 to confirm this appointment. Press 2 to hear other availabilities"

    message = client.menu2 % {time: formatted_time(slot1[:start])}

    tropo.on :event => 'continue', :next => '/handle_menu2.json'
    tropo.ask({
                  name: 'menu2',
                  say: [{
                            value: client.incorrect_option,
                            event: 'nomatch'
                        },
                        {
                            value: message
                        }],
                  choices: {
                      value: "1, 2",
                      mode: 'dtmf'
                  },
                  timeout: 5.0,
                  attempts: 3,
                  required: 'true',
                  bargein: 'true',
              }
    )

    render json: tropo.response, status: 200
  end


  # confirm first appointment or play next 2
  def handle_menu2
    answer = tropo_response[:result][:actions][:menu2][:value]

    case answer
      when '1'
        set_current_slot(answer)
        create_appointment_for_caller
      when '2'
        menu3
      else
        handle_incorrect
    end
  end

  def menu3
    from = session[:slot2].present? ? session[:slot2]['start'] : session[:slot1]['start']
    get_next_two_free_slots(Time.at(from) + 5.minutes)

    # message = "You will now hear the next possible availabilities: "
    # message += "Press 1 for #{formatted_time(slot1[:start])}. Press 2 for #{formatted_time(slot2[:start])}"
    # message += "Press 3 to hear other availabilities. Or press 9 to talk to the client."

    message = client.menu3 % {time1: formatted_time(slot1[:start]), time2: formatted_time(slot2[:start])}

    tropo.on :event => 'continue', :next => '/handle_menu3.json'
    tropo.ask({
                  name: 'menu2',
                  say: [{
                            value: client.incorrect_option,
                            event: 'nomatch'
                        },
                        {
                            value: message
                        }],
                  choices: {
                      value: "1, 2, 3, 9",
                      mode: 'dtmf'
                  },
                  timeout: 5.0,
                  attempts: 3,
                  required: 'true',
                  bargein: 'true',
              }
    )

    render json: tropo.response, status: 200
  end


  def handle_menu3
    answer = tropo_response[:result][:actions][:menu2][:value]

    case answer
      when '1', '2'
        set_current_slot(answer)
        create_appointment_for_caller
      when '3'
        menu3
      when '9'
        forward_to_agent
      else
        handle_incorrect
    end
  end

  def create_appointment_for_caller
    if valid_caller_id # TODO remove, caller_id is validated already
      create_appointment(appointment_params)
    else
      ask_phone_number
    end
  end

  def valid_caller_id
    # TODO, Validate caller_id
    # Tropo says: Callers that have blocked their caller ID will typically have the ID of "Unknown"
    # SuperSAAS only allow digits for phone numbers
    # valid_caller_id = Float(caller_id) rescue false

    !['unknown', '0'].include?(caller_id.try(:downcase))
  end


  def ask_phone_number
    message = client.ask_phone

    tropo.on :event => 'continue', :next => '/create_appointment_with_phone.json'
    tropo.ask({
                  name: 'phone_number',
                  say: [{
                            value: client.incorrect_option,
                            event: 'nomatch'
                        },
                        {
                            value: message
                        }],
                  choices: {
                      value: '[7-15 DIGITS]',
                      mode: 'dtmf'
                  },
                  terminator: '#',
                  timeout: 15.0,
                  attempts: 3,
                  required: 'true',
                  bargein: 'false',
              }
    )

    render json: tropo.response, status: 200
  end

  def create_appointment_with_phone
    # require 'telephone_number'
    # phone = tropo_response[:result][:actions][:phone_number][:value].sub!(/^0+/, '')
    phone = tropo_response[:result][:actions][:phone_number][:value]
    if phone
      # session[:caller_id] = TelephoneNumber.parse(phone, :be).e164_number
      session[:caller_id] = Phonelib.parse(phone).to_s
      create_appointment(appointment_params)
    else
      handle_incorrect
    end
  end

  def send_sms
    @client = Client.find tropo_session[:session][:parameters][:client_id]

    from = voxiplan_sms_sender
    to = tropo_session[:session][:parameters][:to]
    call_id = tropo_session[:session][:parameters][:call_id]
    appointment_time = tropo_session[:session][:parameters][:appointment_time]

    text = client.sms_text % {time: formatted_time(Time.at(appointment_time.to_i))}
    label = "client_id=#{client.id};to=#{to};call_id=#{call_id}"
    tropo = Tropo::Generator.new({voice: client.voice}) do
      message({
                  to: to,
                  from: from,
                  say: {
                      value: text
                  },
                  network: 'SMS',
                  channel: 'TEXT',
                  label: label
              })
    end

    render json: tropo.response, status: 200
  end

  def receive_sms
    logger.info " ********* WE RECEIVED A MESSAGE ******** "
    logger.info tropo_response.inspect
    head :ok
  end

  def hangup
    logger.info " ********* CALL HANGUP ******** "
    logger.info tropo_response.inspect
    head :ok
  end

  private

  # TODO: Delete. No longer used. Moved logic to Webhooks
  # def create_summary(start_date, end_date)
  #   @client ||= current_client
  #   @report = {}
  #   # TODO: Delete. Appointments are now associated to calls instead of client
  #   @report[:total_confirmed_appointments] = 0 || @client.appointments.between(start_date, end_date).count
  #   @report[:total_incoming_calls] = @payloads.calls.in.count
  #   @report[:total_incoming_calls_minutes] = @payloads.calls.in.duration_in_minutes
  #   @report[:total_outgoing_calls] = @payloads.calls.out.count
  #   @report[:total_outgoing_calls_minutes] = @payloads.calls.out.duration_in_minutes
  #   @report[:total_sms] = @payloads.sms_count
  # end

  # TODO: Remove. Now numbers does not directly belongs to client
  def client
    # Find client with phone number
    # @client ||= Client.where(phone: callee_number).or(Client.where(sip: callee_sip)).first
    @client ||= Client.find_by_phone(callee_number)
    @client ||= Client.find_by_sip(callee_sip) if callee_sip.present?
    @client ||= Client.find_by(identifier: identifiers) if identifiers.any?
    # @client ||= Client.first # temp
    @client
  end

  def ivr
    return @ivr if @ivr.present?
    phone = Phonelib.parse(caller_id).sanitized

    if phone.present? && TestIdentifier.pluck(:identifier).include?(callee)
      client =  Client.find_by(phone: phone)
      logger.info "CALL made to test number #{callee} but client not identified with phone: #{phone}" unless client.present?
    end

    @ivr =  client.ivrs.first if client
    @ivr ||= ivr_by_identifier
    # @ivr = Ivr.find(33)
    if @ivr
      logger.info "***************** Identified IVR: #{@ivr.try(:id) || 'nil'} ************** "
      session[:data][:current_ivr_id] = @ivr.id
    else
      logger.info "***************** Could not identify IVR using identifiers: #{identifiers.inspect} ************** "
      reject
    end
    @ivr
  end

  def ivr_by_identifier
    @ivr_by_identifier ||= Identifier.find_by(identifier: identifiers).try(:ivr)
  end

  def identifiers
    [diversion_identifer, account_id, callee_number, callee_sip, callee_sip_map].compact
  end

  def diversion_identifer
    tropo_session[:session][:headers][:diversion].match(/<(.*?)>/)[1].split(';')[0] rescue nil
  end

  def account_id
    return params[:cid] if params[:cid]
    if twilio?
      params['SipHeader_X-Voxiplan-Accountid']
    else
      tropo_session[:session][:headers]['x-voxiplan-accountid'] rescue nil
    end
  end

  def voxiplan_sms_sender
    ENV['VOXINESS_CONFIRMATION_SMS_SENDER']
  end

  def handle_incorrect
    tropo.say(:value => client.incorrect_option)
    forward_to_agent
  end

  def reject
    TwilioEngine.reject if twilio?
  end

  def play_error(error_message)
    tropo.say(:value => error_message)
    forward_to_agent
  end

  def forward_to_agent
    message = client.transferring_call

    tropo.say(value: message)
    if Phonelib.valid?(caller_id)
      tropo.transfer(to: client.agent_number, from: Phonelib.parse(caller_id).to_s)
    else
      tropo.transfer(to: client.agent_number)
    end
    render json: tropo.response, status: 200
  end

  def tropo
    default_options = {
        voice: client.voice,
    }

    @tropo ||= Tropo::Generator.new(default_options)
    @tropo.on :event => 'hangup', :next => '/hangup.json'
    @tropo
  end

  def tropo_response
    @tropo_response ||= Tropo::Generator.parse request.env["rack.input"].read
  end

  def tropo_session
    json_session = request.env["rack.input"].read
    @tropo_session ||= Tropo::Generator.parse json_session rescue nil
  end

  def initial_call_setup
    # reset_session # local testing
    inspect_params

    session[:data] ||= {
      free_slots: {}, # used by ai bot
      existing_appointments: {}, # used by ai bot
    }
    if tropo?
      set_tropo_session_variables
    elsif twilio?
      set_twilio_session_variables
    end
    keys = %i[To From ForwardedFrom ToState CallerCountry CallerState ToZip CallerZip ToCountry CalledZip CalledCity CalledCountry CallerCity FromCountry ToCity FromCity CalledState FromZip FromState]
    call_params = params.slice(*keys)
    call_params = call_params.transform_keys{|k| k.underscore.downcase}
    call_params[:caller_id] = caller_id
    call_params[:tropo_call_id] = call_id
    set_current_call(call_params)
    set_ivr_preference
  end

  def set_tropo_session_variables
    # CallerID
    # tropo_session[:session][:from][:id]
    logger.info ' ********* SET SESSION VARS ******** '
    logger.info " ********* FROM >>> \n#{tropo_session[:session][:from].inspect} \n<<< /FROM"
    logger.info " ********* TO >>> \n#{tropo_session[:session][:to].inspect} \n<<< /TO"
    logger.info " ********* HEADERS >>> \n#{tropo_session[:session][:headers].inspect} \n<<< /HEADERS"
    logger.info " ********* HEADERS KEYS >>> \n#{tropo_session[:session][:headers].keys.inspect} \n<<< /HEADERS KEYS"
    logger.info " ********* HEADERS _TO >>> \n#{tropo_session[:session][:headers][:_to].inspect} \n<<< /HEADERS _TO"

    session[:tropo_session_id] = tropo_session[:session][:id]
    session[:data]['tropo_call_id'] = tropo_session[:session][:call_id]

    # callee number
    session[:data]['callee_number'] = Phonelib.parse(tropo_session[:session][:to][:e164_id]).sanitized

    # callee SIP
    session[:data]['callee_sip'] = tropo_session[:session][:headers][:_to].match(/<(.*?)>/)[1].split(';')[0]
    set_caller_id(tropo_session[:session][:from][:e164_id])
    logger.info " ********* VARS >>> \n#{[session[:data]['caller_id'], session[:data]['callee_number'], session[:data]['callee_sip']]} \n<<< /VARS"
  end

 def set_twilio_session_variables
    # TODO: Delete
    # session[:tropo_session_id] =
    # TODO: Rename column
    session[:data]['tropo_call_id'] = params[:CallSid]

    # callee number
    session[:data]['callee_number'] = Phonelib.parse(params[:To]).sanitized

    # callee SIP
    # session[:data]['callee_sip'] = tropo_session[:session][:headers][:_to].match(/<(.*?)>/)[1].split(';')[0]
    session[:data]['callee_sip'] = params[:To].split(';')[0] if params[:To].match?(/sip/) # does tropo send information after ';' with sip?

    set_caller_id(params[:From])

    logger.info " ********* VARS >>> \n#{[session[:data]['caller_id'], session[:data]['callee_number'], session[:data]['callee_sip']]} \n<<< /VARS"
  end

  def set_caller_id(caller_id)
    # hard codding will not ask phone number
    # we can uncomment this line while testing.
    # caller_id = '32470123456'
    # considering that Tropo will always send us a valid e164 caller_id.
    # Remove preceding '+'
    # session[:data]['caller_id'] = Phonelib.parse(caller_id).sanitized
    # session[:data]['caller_id'] = caller_id

    if caller_id.match?(/sip:/)
      caller_id = caller_id.split('@')[0].gsub('sip:', '')
    end

    phone = Phonelib.parse(caller_id)

    client_country = ivr_by_identifier.client.country rescue nil

    cid =
      if phone.valid?
        puts "****** caller_id #{caller_id} is valid for international format for #{phone.country}"
        voxi_phone(phone)
      elsif Phonelib.valid_for_country? caller_id, client_country
        puts "****** caller_id #{caller_id} is valid for #{client_country} "
        voxi_phone(caller_id, client_country)
      else
        puts "****** caller_id #{caller_id} is NOT valid for #{client_country} "
      end

    session[:data]['caller_id'] = cid
    # current_call.save_data(:caller_id, cid)
    # We can convert caller_id to standard format expecting caller is only from client's country
    #
    # if ivr.try(:client).try(:phone_country)
    #   Phonelib.parse(caller_id, ivr.client.phone_country).e164[1..-1]
    # else
    #   caller_id
    # end
  end

  def set_current_call(params)
    return unless ivr
    params[:client_id] = ivr.client.id
    call_id = ivr.calls.create(params.permit!).id
    session[:data][:current_call_id] = call_id
    session[:data][:client_id] = ivr.client.id
    session[:data][:current_voxi_session_id] = VoxiSession.create(platform: 'call', call_id: call_id, client: ivr.client)
  rescue Exception => e
    puts e.message
  end

  def set_ivr_preference
    return unless ivr
    ivr.preference.each do |k,v|
      session[:data]["ivr_preference_#{k}"] = v
    end

    session[:data]['client_first_name'] = ivr.client.first_name
  end

  def current_call
    Call.find(session[:data][:current_call_id]) if session[:data].try(:[], :current_call_id)
  end

  def tropo?
    tropo_session.present?
  end

  def twilio?
    params['CallSid'].present?
  end

  def caller_id
    session[:data]['caller_id']
  end

  def call_id
    session[:data]['tropo_call_id']
  end

  def callee_number
    session[:data]['callee_number']
  end

  def callee_sip
    session[:data]['callee_sip']
  end

  def callee_sip_map
    sip = session[:data]['callee_sip']
    return unless sip && sip.match(/.voxiplan.sip.twilio.com/)
    sip.split('@')[0].gsub('sip:', '').concat("@voxiplan.com")
  end

  def callee
    callee_number.presence || callee_sip_map.presence || callee_sip
  end

  def agenda_app
    # schedule_id = client.schedule_id
    # checksum = client.checksum
    # SuperSaasParty.new(schedule_id, checksum)
    client.agenda_apps.first
  end

  def formatted_time(time)
    format = if I18n.exists?('time.formats.custom', client.locale)
               :custom
             else
               :long
             end

    l(time, format: format, locale: client.locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  # get first free slot from SuperSAAS and store it in session
  def get_first_free_slot(from=Time.current)
    slots = agenda_app.free_slots(1,from)
    session[:slot1] = {'start' => slots[0]['start'].to_i, 'finish' => slots[0]['finish'].to_i, 'name' => slots[0]['name']}
  end

 # get next slots after from date and store them in session
  def get_next_two_free_slots(from=Time.current)
    slots = agenda_app.free_slots(2,from)
    session[:slot1] = {'start' => slots[0]['start'].to_i, 'finish' => slots[0]['finish'].to_i, 'name' => slots[0]['name']}
    session[:slot2] = {'start' => slots[1]['start'].to_i, 'finish' => slots[1]['finish'].to_i, 'name' => slots[1]['name']}
  end

  def set_current_slot(num)
    session[:current_slot] = "slot#{num}"
  end

  def current_slot
    send(session[:current_slot])
  end

  # Convert strings to DateTime
  def slot1
    @slot1 ||= {name: session[:slot1]['name'], start: Time.at(session[:slot1]['start']).in_time_zone('UTC'), finish: Time.at(session[:slot1]['finish']).in_time_zone('UTC')}
  end

  def slot2
    @slot2 ||= {name: session[:slot2]['name'], start: Time.at(session[:slot2]['start']).in_time_zone('UTC'), finish: Time.at(session[:slot2]['finish']).in_time_zone('UTC')}
  end

  def appointment_params
    # default_params = client.default_params_hash.transform_values{|v| v % {caller_id: caller_id} }
    # p = {start: current_slot[:start], finish: current_slot[:finish], resource_id: current_slot[:name]}
    p = {start: current_slot[:start], finish: current_slot[:finish], resource_id: current_slot[:name], caller_id: caller_id}
    # default_params.merge(p)
  end

  def create_appointment(params = {})
  params.merge!(evt_id: "") if agenda_app.type = 'ClassicAgenda'
    if agenda_app.create_appointment(params)
      handle_appointment_success(current_slot[:start],params)
    else
      play_error(client.appointment_error)
    end
  end

  def handle_appointment_success(time, params)
    # send email to client
    # appointment_params = {start: current_slot[:start], finish: current_slot[:finish], phone: caller_id}
    # ClientNotifierMailer.appointment_confirmation_mail(client, appointment_params).deliver
    # TODO: Use background jobs

    email_invitee = client.service_notifications.where(service_id: session[:data][:choosen_service], automation_type: "confirmation_email_invitee")
    if email_invitee.count.zero?
      email_invitee_subject = t("mails.confirmation_email_invitee.subject").html_safe
      email_invitee_body = t("mails.confirmation_email_invitee.body").html_safe
      invitee_include_cancel_link = false
    else
      email_invitee_subject = email_invitee.first.subject
      email_invitee_body = email_invitee.first.text
      invitee_include_cancel_link = email_invitee.first.is_include_cancel_link
    end

    resource = Resource.find(session[:data][:choosen_resource])
    service = Service.find(session[:data][:choosen_service])
    cancel_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: opts[:evt_id], type: 'cancel') : ''
    reschedule_link = invitee_include_cancel_link ? appointment_widget_url(@ivr.booking_url, event_id: opts[:evt_id], type: 'schedule') : ''
    st_time = Time.at(Time.parse(current_slot[:start])).in_time_zone('UTC')

    pre_confirmation = Service.find_by(id: session[:data][:choosen_service])&.preference["pre_confirmation"] == "true"
    if pre_confirmation
      accept_url = ENV['DOMAIN']+pre_confirmation_acceptance_path(params[:evt_id], locale: nil)
      decline_url = ENV['DOMAIN']+pre_confirmation_cancelation_path(params[:evt_id], locale: nil)
      ClientNotifierMailer.appointment_pre_confirmation_mail(client.email, Customer.find_by(phone_number: caller_id)&.email, formatted_time(current_slot[:start]), caller_id,accept_url,decline_url, nil).deliver
      ClientNotifierMailer.appointment_pre_confirmation_mail_invitee(Customer.find_by(phone_number: caller_id)&.email, formatted_time(current_slot[:start]), caller_id, client.email, email_invitee_subject, email_invitee_body).deliver if Customer.find_by(phone_number: caller_id).present?
    else
      ClientNotifierMailer.appointment_confirmation_mail(client.email, (client.first_name || '') + ' ' + (client.last_name) + ' ' + service&.name, st_time.in_time_zone(client.time_zone), caller_id, ivr, cancel_link, reschedule_link, nil).deliver
      ClientNotifierMailer.appointment_confirmation_mail_invitee(Customer.find_by(phone_number: caller_id)&.email, Customer.find_by(phone_number: caller_id)&.full_name + ' ' + service&.name, st_time.in_time_zone(client.time_zone), caller_id,
                                                                 resource&.name, ivr, email_invitee_subject, email_invitee_body, cancel_link, reschedule_link).deliver
    end

    # TODO: Delete. Appointments are now associated to calls instead of client
    Appointment.create(caller_id: caller_id, tropo_session_id: session[:tropo_session_id], time: time, source: 'IVR', ivr_id: ivr.id, client_id: client.id, 
      resource_id: session[:data][:choosen_resource], service_id: session[:data][:choosen_service],
      event_id: params[:evt_id])
    current_call.update_column(:appointment_time, time) if current_call
    send_sms_to_user(caller_id, current_slot[:start]) if client.confirmation_sms? && is_valid_mobile(caller_id)

    # play_confirmation
    message = client.appointment_success % {time: formatted_time(time)}

    tropo.say(message)
    render json: tropo.response, status: 200
  end

  def send_sms_to_user(to, appointment_time)
    url = 'https://api.tropo.com/1.0/sessions'
    options = {
        query: {
            token: ENV['TROPO_MESSAGING_API_KEY'],
            message_to: to,
            appointment_time: appointment_time.to_i,
            client_id: client.id
        }
    }
    HTTParty.post(url, options)
  end

  def is_valid_mobile(phone_no)
    phone = Phonelib.parse(phone_no)
    (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile)) rescue false
  end
end
