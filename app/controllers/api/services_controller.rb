module Api
  class ServicesController < Api::BaseController
    def index
      if params[:resource_name]
        resources = current_client.resources.active.where("lower(name) = ?",params[:resource_name].downcase)
        result = resources.map{|res| res.services.active.map {|s| {'id' => s.id, 'name' => s.name.presence || s.ename, 'price' => s.price}}}
        result = result[0] if result.count > 0
      elsif params[:resource_id]
        resource = current_client.resources.active.find_by_id(params[:resource_id])
        result = resource.nil? ? nil : resource.services.active.map {|s| {'id' => s.id, 'name' => s.name.presence || s.ename, 'price' => s.price}}
        # result = result[0] if result.count > 0
      else
        first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
        services = first_agenda.is_online_agenda? ? current_ivr.client.services.active.where(ivr_id: current_ivr.id, agenda_type: first_agenda.type) : current_ivr.client.services.active.where(ivr_id: current_ivr.id).ordered
        result = services.map {|s| {'id' => s.id, 'name' => s.name.presence || s.ename, 'price' => s.price}}
      end

      session[:data][:hints] = result.nil? ? [] : result.map{|r| r['name']}.compact.join(", ")
      render json: result || []
    end
  end
end