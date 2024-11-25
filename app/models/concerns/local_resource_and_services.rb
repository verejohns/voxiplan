module LocalResourceAndServices
  def services(resource_id: nil)
    if resource_id.present?
      resource = Resource.find_by_id resource_id
      services = resource.services
    else
      services = ivr.services
    end
    services.active.ordered.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def resources(service_id: nil)
    if service_id.present?
      service = Service.find_by_id service_id
      resources = service.resources
    else
      resources = ivr.resources
    end
    resources.active.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def service(service_id)
    service = client.services.find_by_id(service_id)
    {'id' => service.id, 'name' => service.name}
  end

  def resource(resource_id)
    resource = client.resources.find_by_id(resource_id)
    {'id' => resource.id, 'name' => resource.name}
  end

end