require 'super_saas_party'

class SuperSaas < AgendaApp
  # validates :ss_schedule_id, presence: { message: "SuperSaas schedule_id can't be blank" }
  # validates :ss_checksum, presence: { message: "SuperSaas checksum can't be blank" }

  def free_slots(number_of_slots, after_time=Time.current, options = nil)
    options ||= {}
    options.symbolize_keys!
    @slots = agenda_free_slots(after_time)
    full_day_slots(number_of_slots, after_time) if options[:full_day]
    # Offer only distinct slots
    @slots = @slots.group_by{|s| s['start']}.map{|k,v| v[0]}
    super
  end

  def agenda_free_slots(after_time)
    super_saas.free_slots(after_time)
  end

  def super_saas
    @super_saas ||= SuperSaasParty.new(self.ss_schedule_id, self.ss_checksum)
  end

  def create_appointment(params = {})
    params.symbolize_keys!
    caller_id = params.delete(:caller_id)
    default_params = default_params_hash.transform_values{|v| v % {caller_id: caller_id} }
    response = super_saas.create_appointment(default_params.merge(params))
    response.created?
  end

  def existing_appointments_reminders(params = {})
    []
  end

  def required_attrs(slot)
    attrs = slot.slice('start', 'finish')
    attrs['resource_id'] = slot['id']
    attrs
  end

  def common_required_attrs(attributes)
    { caller_id: attributes[:caller_id] }
  end

  def default_params_hash
    h = {}
    self.ss_default_params.split("\n").each do |line|
      key, value = line.split('=').map(&:strip)
      h[key.to_sym] = value
    end

    return h
  end

  def services(resource_id: nil)
    if resource_id.present?
      resource = Resource.find_by_id resource_id
      services = Resource.where(id: resource.dependent_ids)
    else
      services = ivr.services.where(is_local: true)
    end
    services.active.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def resources(service_id: nil)
    if service_id.present?
      service = Service.find_by_id service_id
      resources = Resource.where(id: service.dependent_ids)
    else
      resources = ivr.resources.where(is_local: true)
    end
    resources.active.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def service(service_id)
    service = Service.find_by_id (service_id)
    {'id' => service.id, 'name' => service.name}
  end

  def resource(resource_id)
    resource = Resource.find_by_id (resource_id)
    {'id' => resource.id, 'name' => resource.name}
  end

end
