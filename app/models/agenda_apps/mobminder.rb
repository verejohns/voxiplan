require 'mobminder_party'

class Mobminder < AgendaApp

  # validates :mm_login, presence: { message: "Mobminder login can't be blank" }
  # validates :mm_pwd, presence: { message: "Mobminder password can't be blank" }
  # validates :mm_kid, presence: { message: "Mobminder key can't be blank" }
  # => [{"start"=>Wed, 26 Sep 2018 18:45:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:00:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}, {"start"=>Wed, 26 Sep 2018 19:00:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:15:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}, {"start"=>Wed, 26 Sep 2018 19:15:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:30:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}]
  # => [{"start"=>Wed, 26 Sep 2018 18:45:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:15:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}, {"start"=>Wed, 26 Sep 2018 18:45:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:15:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}, {"start"=>Wed, 26 Sep 2018 19:00:00 UTC +00:00, "finish"=>Wed, 26 Sep 2018 19:30:00 UTC +00:00, "service_id"=>"15414", "resource_id"=>"13138"}]

  def free_slots(number_of_slots, after_time=Time.current, options = {})
    options.symbolize_keys!
    opts = { from: after_time }
    resources = (options[:resource_id] || "").split(',')

    if resources.size > 1
      resources.each{|r| opts.merge!(resource_type(r) => r)}
    else
      opts.merge! all_resources(options[:service_id], options[:resource_id])
    end

    opts[:duration] = mobminder.service(options[:service_id])['duration']
    opts.merge!(mobminder.tboxing(options[:service_id]))
    all_slots = mobminder.free_slots(opts)
    @slots = all_slots.select{|s| s[:start] > after_time}.map(&:stringify_keys)
    @slots = @slots.first(number_of_slots) if number_of_slots

    if options[:full_day]
      # considering slots are in alphabatically order
      @next_group = @slots.find{|x| x['start'].to_date > after_time.to_date }
      @next_group = @next_group['start'].to_date if @next_group
      @slots.select!{|x| x['start'].to_date == after_time.to_date }
    end

    @slots.each do |slot|
      update = {
          'service_id' => options[:service_id],
          'resource_id' => options[:resource_id],
          'uCals' => opts[:uCals],
          'bCals' => opts[:bCals],
          'fCals' =>  opts[:fCals]
      }
      slot.merge!(update.compact)
    end
    super
  end

  # returns the options to call free_slots with
  # => {bCals: 12, uCals: 123}
  # https://docs.google.com/document/d/1bsqvcRPkmju4dsTAgGkWlXNTPbqTkgwwsoUGzvC5Z8U/edit#
  def all_resources(service_id, resource_id)
    raise "No service_id given" if service_id.blank?
    raise "No resource_id given" if resource_id.blank?

    resource_type = resource_type(resource_id)
    returned = {resource_type => resource_id}
    extra_resources = resources(service_id: service_id).map{|r| { id: r["id"], name: r["name"], type: resource_type(r["id"]) }}
    extra_resources.select!{|r| r[:type] != resource_type}
    # extra_resources.select!{|r| r[:type] == :bCals } if resource_type(resource_id) != :bCals

    extra_resources = extra_resources.group_by{|r| r[:type]}
    extra_resources.each do |k,v|
      returned[k] = v.sample[:id] # take any random
    end
    return returned
  end

  def create_appointment(params = {})
    params.symbolize_keys!

    begin
      params[:id] = params[:evt_id] if params[:evt_id]
      response = mobminder.create_appointment(params)
    rescue => e
      puts e
    end

    {result: response.present?, event: { event_id: response[0][0] }}
  end

  def resource_type(resource_id)
    resource = mobminder.resource(resource_id)
    return unless resource.present?
    # resourceType: type of the planning resource [2 for business agenda lines, 1 for staffing lines, 4 for facultative resources]
    case resource['resourceType']
      when '1'
        :uCals
      when '2'
        :bCals
      when '4'
        :fCals
      else
        raise 'Not supported type'
    end
  end

  def delete_appointment(id)
    response = mobminder.delete_appointment(id: id)
    # response.first['deleted'].present?
    return {result: response.first['deleted'].present?, event: response.first}
  end

  def find_customer(phone: , client_id: nil)
    find_customer_by(:mobile, phone) || find_customer_by(:phone, phone)
  end

  def find_customer_by(key, value)
    mobminder.visitors(key => sanitize(value)).try(:first)
  end

  def is_connected?
    return mobminder ? true : false
  end

  # required params: agenda_customer_id
  def existing_appointments(params = {})
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-visitor id data-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    puts params.inspect
    params[:id] = params[:agenda_customer_id]
    appointments = mobminder.appointments(params)
    appointments.reject!{|a| a['deletorId'].to_i > 0} # ignore deleted
    appointments.map do |a|
      {
          'id' => a['id'],
          'time' => DateTime.parse(a['cueIn']),
          'resource' => a[:resources].map{|r| r[:resourceId]}.join(','),
          'service' => a[:services].try(:[], 0).try(:[], :workCodeId)
      }
    end
  end

  def existing_appointments_reminders(params = {})
    []
  end

  # save agenda customer in local db
  def create_local_customer(customer)
    phone = parse_phone(customer[:mobile])
    fixed_line_phone = parse_phone(customer[:phone])

    local_customer = client.customers.find_by_phone_number(phone.e164) ? client.customers.find_or_initialize_by(phone_number: phone.e164) : client.customers.find_or_initialize_by(phone_number: fixed_line_phone.e164)
    
    local_customer.update(
      eid: customer[:id],
      first_name: customer[:firstname],
      last_name: customer[:lastname],
      email: customer[:email],
      gender: customer[:gender] == 1 ? 'm' : 'f',
      birthday: parse_date(customer[:birthday]),
      city: customer[:city],
      street: customer[:address],
      zipcode: customer[:zipCode],
      phone_country: phone.country,
      phone_number: customer[:phone],
      fixed_line_num: voxi_phone(customer[:phone]),
    )

    local_customer.contacts.find_or_create_by(phone: phone.e164, country: phone.country, phone_type: :mobile, client_id: self.client.id)
    local_customer.contacts.find_or_create_by(phone: fixed_line_phone.e164, country: fixed_line_phone.country, phone_type: :fixed_line, client_id: self.client.id)
    local_customer
  end

  # parse date and handle exception
  # Mobminder returns a '0' value if birthday is not present
  def parse_date(date)
    Date.parse(date) rescue nil
  end


  def create_customer_on_agenda(local_customer_id)
    customer = Customer.find(local_customer_id)
    # phone = sanitize(customer.phone_number)
    params = {
        firstname: customer.first_name&.gsub(/\d+/,"") || 'X.', # Mobminder does not allow number as name
        lastname: customer.last_name&.gsub(/\d+/,"") || 'X.',
        country: customer.phone_country,
        note: customer.recorded_name_url ? "Recorded name: #{customer.recorded_name_url}" : ""
    }
    params[:mobile] = Phonelib.parse(customer.phone_number).e164 if customer.phone_number
    params[:phone] = Phonelib.parse(customer.fixed_line_num).e164 if customer.fixed_line_num
    params[:email] = customer.email if customer.email

    params[:mobile] = "+#{customer.contacts.first.phone.gsub('+','')}" if customer.contacts.first && params[:mobile].blank?
    params[:firstname] = params[:firstname]&.ljust(1,'.')
    params[:lastname] = params[:lastname]&.ljust(2,'.')

    agenda_customer = mobminder.create_visitor(params)

    customer.update(eid: agenda_customer[:id])
  end


  def services(resource_id: nil)
    services = mobminder.services.select{|a| a['ereservable'] == '1'}
    if resource_id
      resource_services = mobminder.workexperts
      resource_services = resource_services.select{|we| we['resourceId'] == resource_id }.map{|we| we['groupId']}

      services.select!{|s| resource_services.include?(s['id'])}
    end
    services.map {|s| {'id' => s['id'], 'name' => encode_utf8(s['name'])}}
  end

  def resources(service_id: nil)
    resources = mobminder.resources
    if service_id
      resource_resources = mobminder.workexperts
      resource_resources = resource_resources.select{|we| we['groupId'] == service_id }.map{|we| we['resourceId']}
      resources.select!{|s| resource_resources.include?(s['id'])}
    end
    resources.map {|s| {'id' => s['id'], 'name' => encode_utf8(s['name'])}}
  end

  def service(service_id)
    service = mobminder.services.find{|service| service['id'] == service_id}
    {'id' => service['id'], 'name' => service['name']}
  end

  def resource(resource_id)
    resource = mobminder.resources.find{|resource| resource['id'] == resource_id}
    {'id' => resource['id'], 'name' => resource['name']}
  end


  def encode_utf8(str)
    str.force_encoding(Encoding::UTF_8)
  end

  def required_attrs(slot)
    attrs = {}
    attrs['cueIn'] = slot['start']
    attrs['cueOut'] = slot['finish']
    attrs['resource_id'] = slot['resource_id']
    attrs['workcodes'] = slot['service_id']
    attrs['uCals'] = slot['uCals']
    attrs['bCals'] = slot['bCals']
    attrs['fCals'] = slot['fCals']
    attrs.compact
  end

  def common_required_attrs(attributes)
    { visitors: attributes[:agenda_customer_id], id: attributes[:existing_appointment_id], service: attributes[:service].to_s, resource: attributes[:resource].to_s }
  end

  def mobminder
    @mobminder ||= MobminderParty.new(self.mm_login, self.mm_pwd, self.mm_kid)
    return @mobminder
  rescue => e
    puts e
    nil
  end
end
