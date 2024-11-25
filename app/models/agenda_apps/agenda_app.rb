class AgendaApp < ApplicationRecord
  include PhoneNumberUtils

  belongs_to :client
  belongs_to :ivr
  delegate :client, to: :ivr

  MAX_TRIES = 10

  ALL_AGENDA_APPS = [
      {name: 'Classic Agendas', logo: 'classic_agendas_logo', type: 'ClassicAgenda'},
      {name: 'Timify', logo: 'timify_logo', type: 'Timify'},
      {name: 'Mobminder', logo: 'mobminder_logo', type: 'Mobminder'},
      {name: 'Super Saas', logo: 'sss_square_logo', type: 'SuperSaas'}
  ]
  validates :type, inclusion: {in: ALL_AGENDA_APPS.map{|a| a[:type]} + ['DummyAgenda']}

  after_initialize :set_default_ss_appointment_params

  def self.model_name
    return super if self == AgendaApp
    AgendaApp.model_name
  end


  def free_slots(number_of_slots, after_time=Time.current, options = {})
    filter_by_time_slot(options) if options[:time_slot] || options[:ampm]
    @slots = number_of_slots ? @slots.first(number_of_slots) : @slots
    @slots.each{|s| s['sid'] = required_attrs(s)}
  end

  def full_day_slots(number_of_slots, after_time)
    day = after_time.to_date
    while @slots.count < number_of_slots && @slots.last['start'].to_date < day + 1 do
      @slots += agenda_free_slots(next_group_after_time(@slots))
    end

    @slots.select!{|x| x['start'].to_date == day }
  end

  def filter_by_time_slot(options)
    puts "* filter_by_time_slot #{options}"
    time_slot = options[:time_slot]
    ampm = options[:ampm]

    start_hour, end_hour =
      if options[:time_slot] # 0912
        [time_slot[0,2], time_slot[2,2]].map(&:to_i)
      elsif ampm
        start_hour = ampm == 'am' ? 0 : 12
        [start_hour, start_hour + 12]
      end

    @slots.select!{|s| s['start'].hour >= start_hour &&  s['start'].hour < end_hour }
  end

  def create_appointment(params = {})
    raise 'Method not defined in child class'
  end

  # finds customer on agenda and creates a copy in local db.
  def find_and_create_customer(caller_id, client_id = nil)
    # REVIEW: Should we check local db first and then agenda to improve performance
    # contact = Contact.find_by(phone: parse_phone(caller_id).e164)
    # return contact.customer if contact
    customer = find_customer(phone: caller_id, client_id: client_id)
    puts " ************ find_and_create_customer ***************"
    puts customer
    return nil unless customer
    # Customer from Agenda sometime contains special characters like `Marie-Solène`
    # In response these are escaped like "Marie-Sol\xC3\xA8ne".
    # This is correctly stored in unicode.
    # If we reload customer from db it gets proper name
    customer = create_local_customer(customer).reload
    customer.update_column :last_active_at, Time.now
    customer
  rescue => e
    puts "********** find_and_create_customer_error ******************"
    puts e
  end

  def group_by_day
    @slots.group_by{|s| s['start'].to_date}
  end

  def groups(count, after_time=Time.current, options = nil)
    options ||= {}
    groups = {}
    time = after_time
    options[:full_day] = true

    # TODO: Prevent infinite loop
    tries = 0

    begin
      client_email = Ivr.find(self.ivr_id).client.email
    rescue => e
      puts e.backtrace.to_yaml
      client_email = ENV['ERROR_MAIL_RECIPIENTS']
    end

    begin
      while tries < MAX_TRIES && groups.count < count
        tries +=1
        slots = free_slots(200, time, options)
        groups[time.to_date] = slots if slots.present?
        time = (@next_group || time.next_day).midnight.to_time
      end
    rescue NoAvalibilityError => e
      puts e
      ClientNotifierMailer.no_availability_email(client_email).deliver_later
      raise StandardError, "Client #{client_email} has no availabilities!"
    end

    groups
  end


  def configure_resources(resource_ids, service_id: nil, random_resource: true)
    # agenda_type = is_online_agenda? ? self.type : "Local"
    agenda_type = self.type
    scoped_resources = self.ivr.resources.not_local.where(agenda_type: agenda_type)
    disable_services_and_resources(service_id)  if service_id.present?
    #scoped_resources.update_all(enabled: false) if service_id.present?
    return if resource_ids.blank?
    resource_ids.map do |resource_id|
      resource = resource(resource_id)
      local_resource = scoped_resources.
        find_or_initialize_by(eid: resource['id'], ivr_id: ivr.id, agenda_type: agenda_type)
      local_resource.update(resource_service_attrs(local_resource, resource['name']))
      configure_resource_service(service_id, local_resource,true, random_resource) if service_id
      local_resource.id
    end
  end

  def configure_services(service_ids, resource_id: nil, random_resource: true)
    # agenda_type = is_online_agenda? ? self.type : "Local"
    agenda_type = self.type
    scoped_services = self.ivr.services.not_local.where(agenda_type: agenda_type)
    disable_services_and_resources(resource_id, true)  if resource_id.present?
    return if service_ids.blank?
    service_ids.map do |service_id|
      service = service(service_id)
      local_service = scoped_services.
        find_or_initialize_by(eid: service['id'], ivr_id: ivr.id, agenda_type: agenda_type)

      #local_service.update_attributes!(ename: service['name'], enabled: true)
      new_attr = resource_service_attrs(local_service, service['name']).merge(random_resource: random_resource)
      local_service.update(new_attr)
      configure_resource_service(resource_id, local_service, false, random_resource) if resource_id
      local_service.id
    end
  end

  def configure_resource_service(eid, obj, is_service=false, random_resource=true)
    if is_service
      service_ids = configure_services([eid], random_resource: random_resource)
      ResourceService.find_or_create_by(resource: obj, service_id: service_ids.first) if service_ids.present?
    else
      resource_ids = configure_resources([eid])
      ResourceService.find_or_create_by(resource_id: resource_ids.first, service: obj) if resource_ids.present?
    end
  end

  def configure_local_services(service_ids, resource_id)
    local_resource = (Resource.find resource_id)
    ivr_resource = Resource.find_or_initialize_by(resource_id: local_resource.id, name: local_resource.name, ivr_id: local_resource.ivr_id)
    ivr_resource.is_local, ivr_resource.enabled = nil, true
    ivr_resource.save
    ivr_resource.resource_services.delete_all
    return if service_ids.blank?
    service_ids.each do |service_id|
      ResourceService.find_or_create_by(resource_id: ivr_resource.id, service_id: service_id.to_i)
    end
  end

  def configure_local_resources(resource_ids, service_id)
    local_service = (Service.find service_id)
    ivr_service = Service.find_or_initialize_by(service_id: local_service.id, name: local_service.name, ivr_id: local_service.ivr_id)
    ivr_service.is_local, ivr_service.enabled = nil, true
    ivr_service.save
    ivr_service.resource_services.delete_all
    return if resource_ids.blank?
    resource_ids.each do |resource_id|
      ResourceService.find_or_create_by(resource_id: resource_id.to_i, service_id: ivr_service.id)
    end
  end

  def _id_attr
    :eid
  end

  def active_services(resource_id: nil, ivr_id: nil)
    scope = ivr_id.nil? ? self.ivr : Ivr.find(ivr_id)
    if self.class.name == "ClassicAgenda"
      scope = scope.resources.find_by(id: resource_id) if resource_id
    else
      scope = scope.resources.find_by(_id_attr => resource_id, agenda_type: self.class.name) if resource_id
    end

    if self.class.name == "DummyAgenda"
      active_services = scope.services.active.ordered.not_local.where(agenda_type: "ClassicAgenda") rescue false
    else
      active_services = scope.services.active.ordered.not_local.where(agenda_type: self.class.name) rescue false
      active_services = active_services.select { |active_service| active_service.preference["phone_assistant_enabled"] == 'true' } if self.class.name == "Mobminder" || self.class.name == "Timify"
    end
    return [] unless active_services.present?

    active_services.map {|s| {'id' => s.send(_id_attr), 'name' => s.name.presence || s.ename, 'price' => s.price}}
  end

  def active_resources(service_id: nil, ivr_id: nil)
    scope = ivr_id.nil? ? self.ivr : Ivr.find(ivr_id)
    if self.class.name == "DummyAgenda"
      scope = service = scope.services.find_by(_id_attr => service_id, agenda_type: "ClassicAgenda") if service_id
      active_resources = scope.resources.active.ordered.not_local.where(agenda_type: "ClassicAgenda") rescue false
    else
      scope = service = scope.services.find_by(_id_attr => service_id, agenda_type: self.class.name) if service_id
      active_resources = scope.resources.active.ordered.not_local.where(agenda_type: self.class.name) rescue false
    end

    return [] unless  active_resources.present?
    active_resources = [active_resources.sample] if service && service.random_resource
    active_resources.map {|s| {'id' => s.send(_id_attr), 'name' => s.name.presence || s.ename}}
  end

  def is_connected?
    raise NotImplementedError, 'Should be implemented in subclasses'
  end

  # required params: agenda_customer_id
  def existing_appointments(params = {})
    raise NotImplementedError, 'Should be implemented in subclasses'
  end

  # required params: agenda_customer_id
  def existing_appointments_reminders(params = {})
    raise NotImplementedError, 'Should be implemented in subclasses'
  end

  def groups_old(number, after_time=Time.current, preferences = {})
    num_of_slots = 500

    if preferences[:date]
      time = Time.parse(preferences[:date])
      slots = free_slots(num_of_slots, time)
      gslots = slots.group_by{|s| s['start'].to_date == time.to_date}[true]
    else
      slots = free_slots(num_of_slots, after_time)
      gslots = slots.group_by{|s| s['start'].to_date}
    end

    start_hour, end_hour =
      if preferences[:timeslot] # 0912
        timeslot = preferences[:timeslot]
        [timeslot[0,2], timeslot[2,2]]
      elsif preferences[:ampm]
        start_hour = preferences[:ampm] == 'AM' ? 0 : 12
          [start_hour, start_hour + 12]
      end

    gslots.each{|_,gs| gs.select!{|s| s['start'].hour >= start_hour &&  s['start'].hour < end_hour }} if start_hour && end_hour

    # trim blank
    gslots.select!{|_, gs| gs.present?}
    puts "********* gslost before map #{gslots.to_yaml}"

    # [{start:1, finish: 2}, {start: 2, finish: 3}]
    gslots = gslots.map{|_, gs| {'start' => gs.min{|s| s['start']}['start'], 'finish' => gs.max{|s| s['start']}['start']} }

    # adding +1 to be on save end, as sometimes an api call does not returns all slots of a day.
    while gslots.count < number + 1
      more_gslots = groups(number - gslots.count, next_group_after_time(slots), preferences)
      gslots = (gslots << more_gslots).flatten.group_by{|gs| gs['start'].to_date }.map{|_, gs| {'start' => gs.min{|s| s['start']}['start'], 'finish' => gs.max{|s| s['start']}['finish']}}
    end

    puts "********* gslost after #{gslots.to_yaml}"
    gslots.first(number)
  end

  def next_group_after_time(slots)
    slots.max{|g| g['start']}['finish']
  end

  def is_online_agenda?
    ["Mobminder", "Timify"].include? self.class.name
  end

  def get_agenda_services
    agenda_services.where(agenda_type: self.class.name) rescue []
  end

  def get_agenda_resources
    agenda_resources.where(agenda_type: self.class.name) rescue []
  end

  def disable_services_and_resources(eid, is_resource=false)
    if is_resource
      resource = self.ivr.resources.find_by_eid(eid)
      resource.resource_services.delete_all rescue nil
      #resource.services.update_all(enabled: false) if resource.present?
    else
      service = self.ivr.services.find_by_eid(eid)
      service.resource_services.delete_all rescue nil
      #service.resources.update_all(enabled: false) if service.present?
    end
  end


  # We don't need to save some attributes with each slots i-e customer_id is common
  # We should also consider this approach for other attributes like resource_id and service_id
  # Child classes should implement
  def common_required_attrs(attributes)
    {}
  end

  def self.filter_params params_busiess_hour
    business_hours = {}
    business_days = params_busiess_hour.keys
    (business_days || []).each do |bday|
      if params_busiess_hour[bday][:on]=='true'
        business_hours[bday] = []
        params_busiess_hour[bday][:hours].values.each do |hours|
          hours["from"] =  hours["from"].to_time&.strftime("%H:%M")
          hours["to"] =  hours["to"].to_time&.strftime("%H:%M")
          business_hours[bday].push(hours.as_json)
        end
      end
    end
    return business_hours
  end

  def configure_default_resource_and_service
    obj = AgendaApp.find self.id
    return obj&.is_online_agenda? || obj&.ivr&.agenda_resources.present?
    obj.configure_resources(
      [client.default_resource.id],
      service_id: client.default_service.id,
      random_resource: true
    )
  end

  private
  def set_default_ss_appointment_params
    self.ss_default_params ||= <<~EOS
      full_name=To complete
      email=to-complete@example.com
      address=To complete
      mobile=To complete
      phone=To complete
      country=BE
      description=To complete
      super_field=%{caller_id}
    EOS
  end

  def resource_service_attrs(object, name)
    {
      ename: object.ename || name,
      name: object.name || name,
      enabled: true,
    }
  end
end
