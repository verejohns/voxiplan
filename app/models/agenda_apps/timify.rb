require 'timify_ruby'

class Timify < AgendaApp
  def self.handle_access(response)
    agenda = where(timify_email: response[:email]).take
    access_token = response[:type] == 'unauthorized' ? nil : response[:access_token]
    agenda.update_attributes(timify_access_token: access_token) if agenda
  end

  # required
  # service_id
  # date
  def free_slots(number_of_slots, after_time=Time.current, options = {})
    options.symbolize_keys!
    service_id = options[:service_id]
    resource_id = options[:resource_id]
    puts options
    params = {
      service_id: service_id,
      resource_id: resource_id,
      days: days(after_time),
      company_id: self.timify_company_id,
      timezone: 'UTC'
    }.compact
    puts "********* timify_params ************"
    puts params
    availabilities = timify_availabilities(params)
    puts availabilities
    duration = availabilities.service.duration

    @slots = availabilities.slots.map do |slot|
      slot['times'].map do |time|
        start = DateTime.parse(slot['day']+ 'T' + time).in_time_zone
        st = start
        {
          'service_id' => service_id,
          'resource_id' => resource_id,
          'start' => start,
          'finish' => start + duration.minutes
        }
      end
    end.flatten

    if options[:full_day]
      # considering slots are in alphabatically order
      @next_group = @slots.find{|x| x['start'].to_date > after_time.to_date }
      @next_group = @next_group['start'].to_date if @next_group
      @slots.select!{|x| x['start'].to_date == after_time.to_date }
    end

    @slots.select!{|s| s['start'] > after_time}
    @slots = @slots.group_by {|s| s['start']}.map {|k, v| v[0]} unless resource_id.present?
    super
  end

  # required params
  # -> resource_id
  # -> datetime
  # -> duration
  # -> title or service_id
  def create_appointment(params = {})
    params.symbolize_keys!
    set_resource_ids!(params)
    set_datetime_format!(params)

    id = params.delete(:id)

    if id && id != 0
      response = timify_client.appointments.update(id, params)
    else
      response = timify_client.appointments.create(params)
    end

    {result: response&.id.present?, event: { event_id: response&.id }}
  end


  # required params
  # -> resource_id
  # -> datetime
  # -> duration
  # -> title or service_id
  def update_appointment(params = {})
    params.symbolize_keys!
    set_resource_ids!(params)
    set_datetime_format!(params)
    id = params.delete(:appointment_eid)
    response = timify_client.appointments.update(id, params)

    # REVIEW: See how it works in case of failure.
    {result: response&.id.present?, event: { event_id: response&.id }}
  end

  def delete_appointment(id)
    result = timify_client.appointments.delete(id)
    result.status == 1
    return {result: result}
  rescue RuntimeError
    false
  end

  def services(resource_id: nil)
    services = timify_client.services.list(limit: 100, bookable: true)
    services.select! {|s| timify_resource_ids(s).include?(resource_id)} if resource_id
    services.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def resources(service_id: nil)
    # resources = timify_client.resources.list(bookable: true, limit: 100)
    resources = timify_client.resources.list(limit: 100)
    service = get_service(service_id) if service_id
    resources.select! {|r| timify_resource_ids(service).include?(r.id)} if service
    resources.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def is_connected?
    result = timify_client.services.list(limit: 1)
    return result ? true : false
  rescue => e
    puts e
    return false
  end

  def existing_appointments(params = {})
    params[:customer_id] = params.delete(:agenda_customer_id)
    params[:from_date] ||= Date.current
    params[:to_date] ||= Date.current + 1.months
    appointments = timify_client.appointments.list(params)
    appointments = appointments.map do |a|
      {
        'id' => a.id,
        'time' => DateTime.parse(a.start_date).in_time_zone,
        'resource' => a.resources.map(&:id).first,
        'service' => a.service_id
      }
    end
    appointments.delete_if {|x| x['time'] < Time.current }
  end

  def existing_appointments_reminders(params = {})
    []
  end

  def get_service(service_id)
    timify_client.services.find(service_id)
  end

  def get_resource(resource_id)
    timify_client.resources.find(resource_id)
  end

  def service(service_id)
    service = get_service(service_id)
    {'id' => service.id, 'name' => service.name}
  end

  def resource(resource_id)
    resource = get_resource(resource_id)
    {'id' => resource.id, 'name' => resource.name}
  end

  def required_attrs(slot)
    attrs = slot.slice('resource_id', 'service_id')
    attrs['datetime'] = slot['start']
    attrs['duration'] = ((slot['finish'] - slot['start']) / 60).to_i
    attrs
  end

  def common_required_attrs(attributes)
    {
      customer_id: attributes[:agenda_customer_id],
      id: attributes[:existing_appointment_id]
    }
  end

  def next_group_after_time(slots)
    # for tropo we need to send a date instead of datetime
    slots.max {|g| g['start']}['finish'] + 1.day
  end

  def find_customer(phone: , client_id: nil)
    phone = parse_phone(phone)
    puts "************ find_customer_phone *************"
    puts phone
    page = 0
    cus = nil

    while true
      page = page + 1
      customers = timify_client.customers.list({ page: page, limit: 100 })
      c = customers.find do |customer|
        mobile_phone = customer_phone(customer, 'mobilePhone')
        landline_phone =  customer_phone(customer, 'landlinePhone')
        mobile_phone == phone || landline_phone == phone
      end
      puts "********* customer_find **********"
      puts c
      cus = c
      break if c || customers.count < 100
    end

    cus
  rescue => e
    puts "************ find_customer_timify *************"
    puts e
  end

  # Finds phone number field for Timify customer
  # - customer: timify_customer
  # - key:
  #   - mobilePhone
  #   - landlinePhone
  #
  # returns Phonelib::Phone
  def customer_phone(customer, key)
    phone = find_field(customer.fields, key)
    return unless phone && phone.value.present?

    phone_number = JSON.parse(phone.value)
    parse_phone(phone_number['phone'], phone_number['country'])
  end

  # save agenda customer in local db
  def create_local_customer(customer)
    phone = customer_phone(customer, 'mobilePhone')
    puts "************ create_local_customer *************"
    puts phone
    fixed_line_phone = customer_phone(customer, 'landlinePhone')
    local_customer = client.customers.find_or_initialize_by(phone_number: phone.e164)
    puts "************ local_customer *************"
    puts local_customer.inspect
    local_customer.update(
      eid: customer.id,
      first_name: customer.first_name,
      last_name: customer.last_name,
      email: customer.email,
      gender: customer.gender,
      birthday: customer.birthday,
      city: customer.city,
      street: customer.street,
      zipcode: customer.zipcode,
      phone_country: phone.country,
      phone_number: phone.e164,
      fixed_line_num: voxi_phone(fixed_line_phone),
      )

    local_customer.contacts.find_or_create_by(phone: phone.e164, country: phone.country, phone_type: :mobile, client_id: self.client.id) if phone
    local_customer.contacts.find_or_create_by(phone: fixed_line_phone.e164, country: fixed_line_phone.country, phone_type: :fixed_line, client_id: self.client.id) if fixed_line_phone
    local_customer
  rescue => e
    puts "************ create_local_customer_error **************"
    puts e
  end

  # we can perform this in background to improve performance
  def create_customer_on_agenda(local_customer_id)
    customer = Customer.find(local_customer_id)
    customer.birthday = Date.parse(customer.birthday)
    agenda_customer = create_customer_on_timify(customer)
    customer.update(eid: agenda_customer.id)
  rescue => e
    puts e
    puts customer.inspect
    customer.destroy
    raise 'Invalid Birthday Format'
  end

  def timify_client
    TimifyRuby::Client.new(
      ENV['TIMIFY_APP_ID'],
      ENV['TIMIFY_APP_SECRET'],
      self.timify_company_id
    )
  end

  private

  # Returns list of resources that can perform given service
  def timify_resource_ids(service)
    service.dependencies.map{|d| d['resourcesIds']}.flatten
  end

  # generate array of 30 days that we can use to get free slots
  def days(time)
    date = time.to_date
    (date...date + 30.days).map(&:to_s)
  end

  def timify_availabilities(params)
    set_resource_ids!(params)
    timify_client.call(:get, '/booker-services/availabilities/', query: params)
  rescue => e
    puts e.message
  end

  # https://devs.timify.com/en-gb/#/api-reference/post-customers
  def create_customer_on_timify(customer)
    timify_client.call(:post, '/customers', body: {
      customfields: create_custom_fields(custom_params(customer))
    })
  end

  def custom_fields
    @custom_fields ||=
      timify_client.call(:get, '/customers/customfields/')
  end

  def create_custom_fields(params = {})
    params.map do |key, value|
      { id: custom_field(key).id, value: value }
    end
  end

  def find_field(fields, key)
    fields.find { |f| f['default_id'] == key.to_s }
  end

  def custom_field(key)
    find_field(custom_fields, key)
  end

  # Returns params used to create customer on Timify
  # TODO: Add all contacts while creating customer on Timify
  # Currently using only one mobile and fixed_line contact
  def custom_params(customer)
    {
      firstName: customer.first_name || 'X.',
      lastName: customer.last_name || 'X.',
      email: customer.email,
      mobilePhone: customer_mobile_phone(customer),
      landlinePhone: customer_fixed_line_phone(customer),
      birthday: customer.birthday,
      notes: "Recorded name: #{customer.recorded_name_url}"
    }
  end

  #  - customer: Local customer
  #  - phone_type: Options :mobile or :fixed_line
  def customer_contact(customer, phone_type)
    customer.contacts.find do |contact|
      contact.parsed_phone.type == phone_type
    end.try(:e164)
  end

  # If phone_number column in customer exists then use that
  #    otherwise find from contacts
  def customer_mobile_phone(customer)
    num = customer.phone_number || customer_contact(customer, :mobile)
    timify_phone(num)
  end

  def customer_fixed_line_phone(customer)
    num = customer.fixed_line_num || customer_contact(customer, :fixed_line)
    timify_phone(num)
  end

  def timify_phone(phone_number)
    return unless phone_number.present?

    phone = Phonelib.parse(phone_number)

    {
      phone: phone.e164,
      country: phone.country,
      prefix: phone.country_code,
      number: phone.national.gsub(' ', '')
    }.to_json
  end


  # Adds array of resource_ids to params
  # We get single resource_id in params
  # New Timify API require array of resource_ids
  def set_resource_ids!(params)
    return unless params[:resource_id].present?

    params[:resource_ids] = [params.delete(:resource_id)]
  end

  # Timify accepts time in UTC
  def set_datetime_format!(params)
    params[:datetime] = params[:datetime].utc
  end
end
