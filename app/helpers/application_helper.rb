module ApplicationHelper

  def namespace
    ENV['KETO_NAMESPACE'] || ''
  end

  def ory_url
    ENV['ORY_SDK_KETO_URL'] || "https://recursing-khorana-douoygtthk.projects.oryapis.com"
  end

  def ory_access_token
    ENV['ORY_ACCESS_TOKEN'] || ''
  end

  def check_ory_session
    unless request.env['PATH_INFO'] == '/signin' or request.env['PATH_INFO'] == '/signup' or request.env['PATH_INFO'] == '/post_login' or request.env['PATH_INFO'] == '/post_registration' or request.request_method == 'POST'
      if session[:ory_identity] == nil || session[:ory_session_token] == nil
        redirect_to (ENV['ORY_URL'] || '') + '/self-service/login/browser'
      end
    end
  rescue => e
    puts e
    redirect_to (ENV['ORY_URL'] || '') + '/self-service/login/browser'
  end

  def twilioclient
    account_sid = ENV['ACCOUNT_SID']
    auth_token = ENV['AUTH_TOKEN']
    Twilio::REST::Client.new(account_sid, auth_token)
  end

  def dev_twilioclient
    account_sid = ENV['TEST_ACCOUNT_SID']
    auth_token = ENV['TEST_AUTH_TOKEN']
    Twilio::REST::Client.new(account_sid, auth_token)
  end

  def is_invalid_email(email)
    puts "*** checking email address with abstractAPI - email address: #{email} ***"
    return false if email.include? "@e.rainforestqa.com"
    response = HTTParty.get("https://emailvalidation.abstractapi.com/v1/?api_key=#{ENV['EMAIL_VALIDATION_API_KEY']}&email=#{email}")
    response['is_valid_format']['value'] == false || response['is_disposable_email']['value'] == true || response['is_mx_found']['value'] == false || response['deliverability'] != 'DELIVERABLE'
  end

  def current_client
    Client.where(ory_id: session[:ory_identity].id).first if session[:ory_identity]
  rescue => e
    puts "*********** ory_client_error_helper ************"
    puts e
    return nil
  end

  def my_organizations
    owner = Organization.find_by_client_id(current_client.id)
    my_organizations = []

    my_organizations = [
      {
        id: owner.id,
        name: owner.name,
        current: session[:current_organization].id == owner.id
      }
    ] if owner

    invitations = Invitation.where(to_email: current_client.email, status: 'accepted')

    invitations.each do |invitattion|
      my_organizations.push({
        id: invitattion.organization_id,
        name: invitattion.organization.name,
        current: session[:current_organization].id == invitattion.organization_id
      })
    end

    my_organizations
  end

  def checkRelationTuple (object, relation, subject)
    params = {
      namespace: namespace,
      object: object,
      relation: relation,
      subject_id: subject
    }

    response = HTTParty.post(ory_url + "/relation-tuples/check", {headers: { 'Authorization' => 'Bearer ' + ory_access_token }, body: JSON.generate(params)})

    puts "check relation - ", object, relation, subject

    return response.code == 200 && response["allowed"]
  end

  def deleteRelationTuple (object, relation, subject)
    response = HTTParty.delete(ory_url + "/admin/relation-tuples?namespace=" + namespace + "&object=" + object + "&relation=" + relation + "&subject_id=" + subject, { headers: { 'Authorization' => 'Bearer ' + ory_access_token } })

    if response.code == 204
      puts "Delete Relation Tupple Success!", object, relation, subject
    else
      puts "Delete Relation Tupple Error!"
    end
  end

  def deleteRelationTupleSet (object, relation, subObject, subRelation)
    response = HTTParty.delete(ory_url + "/admin/relation-tuples?namespace=" + namespace + "&object=" + object + "&relation=" + relation + "&subject_set.namespace=" + namespace + "&subject_set.object=" + subObject + "&subject_set.relation=" + subRelation, { headers: { 'Authorization' => 'Bearer ' + ory_access_token } })

    if response.code == 204
      puts "Delete Relation Tupple Success!", object, relation, subObject, subRelation
    else
      puts "Delete Relation Tupple Error!"
    end
  end

  def addRelationTuple (object, relation, subject)
    params = {
      namespace: namespace,
      object: object,
      relation: relation,
      subject_id: subject
    }

    response = HTTParty.put(ory_url + "/admin/relation-tuples", {headers: { 'Authorization' => 'Bearer ' + ory_access_token }, body: JSON.generate(params)})

    if response.code == 201
      puts "Add Relation Tupple Success!", object, relation, subject
    else
      puts "Add Relation Tupple Error!"
    end
  end

  def addRelationTupleSet (object, relation, subObject, subRelation)
    params = {
      namespace: namespace,
      object: object,
      relation: relation,
      subject_set: {
        namespace: namespace,
        object: subObject,
        relation: subRelation
      }
    }

    response = HTTParty.put(ory_url + "/admin/relation-tuples", {headers: { 'Authorization' => 'Bearer ' + ory_access_token }, body: JSON.generate(params)})

    if response.code == 201
      puts "Add Relation Tupple Success!", object, relation, subObject, subRelation
    else
      puts "Add Relation Tupple Error!"
    end
  end

  def industries
    ['Select Industry *', 'Doctors & Dentists', 'Automotive Services', 'Beauty & Massage', 'Coaching & Consulting', 'Photography & Film', 'Hairdressers', 'Craftsmen & Repair', 'Physioth. & Ostheopathy', 'Sports & Leisure', 'Tattoos & Piercings', 'Education & Training', 'Others']
  end

  def has_error_on(field)
    'has-error' if resource && resource.errors[field].present?
  end

  def error_on(resource, field)
    resource.errors[field].join(',') if resource
  end

  def bootstrap_class_for flash_type
    { success: "alert-success", error: "alert-danger", alert: "alert-warning", notice: "alert-info" }[flash_type.to_sym] || flash_type.to_s
  end

  def available_locales
    [:en, :fr, :el, :de, :it]
  end

  def full_day_name(short_name)
    case short_name
      when :mon, 'mon' then t(:"date.day_names")[1]
      when :tue, 'tue' then t(:"date.day_names")[2]
      when :wed, 'wed' then t(:"date.day_names")[3]
      when :thu, 'thu' then t(:"date.day_names")[4]
      when :fri, 'fri' then t(:"date.day_names")[5]
      when :sat, 'sat' then t(:"date.day_names")[6]
      when :sun, 'sun' then t(:"date.day_names")[0]
    end
  end

  def my_message


  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      alert_background = "bg-primary"
      alert_background = "bg-danger" if msg_type == "error"
      alert_background = "bg-warning" if msg_type == "alert"
      alert_background = "bg-info" if msg_type == "notice"
      alert_background = "bg-success" if msg_type == "success"
      concat(content_tag(:div, class: "alert alert-dismissible #{alert_background} d-flex flex-column flex-sm-row p-5 mb-10", style:"margin-top: -20px") do
        concat content_tag(:div, message, class: "d-flex flex-column text-white fw-bolder pe-0 pe-sm-10")
        concat content_tag(:button, "", class: "btn-close", data: {"bs-dismiss": "alert"}, "aria-label": "Close")
      end)
    end
    nil
  end

  def clear_flash
    flash.clear
  end

  def get_event_trigger_path
    cronofy_event_trigger_url
  end

  def create_event_trigger(service, resource, event_data, access_token, calendar_id)
    begin
      reminder = service.reminder
      if reminder.advance_time_duration == '-'
        offset_time = reminder.advance_time_offset
        offset_duration = reminder.time_duration
        transition_option = { "before": "event_start", "offset": {"minutes": offset_time.to_i} } if offset_duration == 'minutes'
        transition_option = { "before": "event_start", "offset": {"hours": offset_time.to_i} } if offset_duration == 'hours'
        transition_option = { "before": "event_start", "offset": {"minutes": offset_time.to_i * 24 * 60} } if offset_duration == 'days' # convert day to minutes

        headers = {
          "Content-Type"  => "application/json",
          "Authorization" => "Bearer " + access_token
        }
        query = {
          "event_id": event_data[:id],
          "summary": event_data[:summary],
          "start": event_data[:start],
          "end": event_data[:end],
          "subscriptions": [
            {
              "type": "webhook",
              "uri": get_event_trigger_path,
              # "uri": "https://c405-23-105-155-2.ngrok.io/event_trigger?locale=en",
              "transitions": [ transition_option ]
            }
          ]
        }

        api_path = ApplicationController.helpers.get_api_center_url(resource.client.data_server) + '/v1/calendars/' + calendar_id + '/events'
        response = HTTParty.post(api_path, { headers: headers, body: JSON.generate(query) })
        if response.nil?
          event_trigger = EventTrigger.new(event_id: event_data[:id], trigger_id: '', offset_time: offset_time, offset_duration: offset_duration)
          event_trigger.save
        end
      end
    rescue => e
      puts "creation event trigger failure (application helper) ~~~~~~~~~~~~" + e.message
    end
  end
  def get_selected_agenda_group_availabilities obj
    obj.parameters["after_time"].gsub(/[^A-Za-z]/, '').capitalize
  end

  def parse_date(date)
    return nil unless date.present?
    date.strftime("%d/%m/%Y %H::%M")
  end

  def current_path
    request.path
  end

  def appointment_menu3_placeholder(key)
    t("static_ivr.appointment_group_menu3.#{key.gsub('key','time')}")
  end

  def current_translations(filter_language = "")
    @translations ||= I18n.backend.send(:translations)
    if filter_language.present?
      @translations[filter_language.parameterize.to_sym].with_indifferent_access
    else
      @translations[I18n.locale].with_indifferent_access
    end
  end

  def check_appointment_status_class(type)
    if type == "new"
      'kt-font-brand'
    elsif type == "modified"
      'kt-font-success'
    else
      'kt-font-danger'
    end
  end

  def europe_codes
    ISO3166::Country.find_all_countries_by_region('Europe').map(&:alpha2)
  end

  def availabilities_hours params_hours
    business_hours = {}
    business_days = params_hours&.keys
    (business_days || []).each do |bday|
      if params_hours[bday][:on]=='true'
        business_hours[bday] = []
        from_hours = params_hours[bday]["from"] || params_hours[bday][:from]
        to_hours = params_hours[bday]["to"] || params_hours[bday][:to]
        from_hours.each_with_index do |from, index|
          hours = {'from': from.to_time&.strftime("%H:%M"), 'to': to_hours[index].to_time&.strftime("%H:%M")}
          business_hours[bday].push(hours.as_json)
        end
      end
    end
    return business_hours
  end

  def override_hours params_hours
    business_hours = {}
    business_days = params_hours&.keys
    (business_days || []).each do |bday|
      business_hours[bday] = []
      from_hours = params_hours[bday]["from"] || params_hours[bday][:from]
      to_hours = params_hours[bday]["to"] || params_hours[bday][:to]
      from_hours.each_with_index do |from, index|
        hours = {'from': from.to_time&.strftime("%H:%M"), 'to': to_hours[index].to_time&.strftime("%H:%M")}
        business_hours[bday].push(hours.as_json)
      end
    end
    return business_hours
  end

  def get_token(client, calendar_id)
    application_calendars = client.application_calendars.where(calendar_id: calendar_id)
    if application_calendars.count.zero?
      current_client.agenda_apps.each do |agenda|
        if agenda.calendar_id == calendar_id
          return {:access_token => agenda.cronofy_access_token, :refresh_token => agenda.cronofy_refresh_token, :agenda_type => agenda.type}
        end
      end
    else
      application_calendar = application_calendars.first
      return {:access_token => application_calendar.access_token, :refresh_token => application_calendar.refresh_token, :agenda_type => 'dummy'}
    end
  end

  def fetch_eur_rate
    bank = Money::Bank::Uphold.new
    Money.default_bank = bank
    # Money.locale_backend = nil
    eurrate = Money.us_dollar(100).exchange_to('EUR')
    eurrate = Money.euro(100).exchange_to('USD')
    rate = eurrate.cents.to_f/100
    rate
  end

  def fetch_user_country(client)
    begin
      user_country_code = ISO3166::Country.find_country_by_alpha2(client.country_code).alpha2
    rescue Exception => e
      puts e.message
      user_country_code = 'BE'
    end
    user_country_code
  end

  def fetch_margin_val(mrgn)
    rate_applied = (100 + mrgn).to_f/100
    rate_applied
  end

  def fetch_voice_margin(vdata)
    default_margin = vdata.include?(:margin) ? vdata[:margin] : nil
    inbound_local_margin = default_margin
    inbound_mobile_margin = default_margin
    outbound_margin = default_margin

    if vdata.include? :inbound
      inbound_local_margin = vdata[:inbound]
      inbound_mobile_margin = vdata[:inbound]
    end

    if vdata.include? "inbound"
      inbound_local_margin = vdata['inbound'][:local] if vdata['inbound'].include? :local
      inbound_mobile_margin = vdata['inbound'][:mobile] if vdata['inbound'].include? :mobile
    end

    outbound_margin = vdata[:outbound] if vdata.include? :outbound
    { inbound_local: inbound_local_margin, inbound_mobile: inbound_mobile_margin, outbound: outbound_margin }
  end

  def fetch_sms_margin(sdata)
    default_margin = sdata.include?(:margin) ? sdata[:margin] : nil
    inbound_margin = default_margin
    outbound_margin = default_margin
    inbound_margin = sdata[:inbound] if sdata.include? :inbound
    outbound_margin = sdata[:outbound] if sdata.include? :outbound
    { inbound: inbound_margin, outbound: outbound_margin}
  end

  def fetch_phone_margin(pdata)
    default_margin = pdata.include?(:margin) ? pdata[:margin] : nil
    national_margin = default_margin
    local_margin = default_margin
    mobile_margin = default_margin
    national_margin = pdata[:national] if pdata.include? :national
    local_margin = pdata[:local] if pdata.include? :local
    mobile_margin = pdata[:mobile] if pdata.include? :mobile
    { national: national_margin, local: local_margin, mobile: mobile_margin}
  end
end
