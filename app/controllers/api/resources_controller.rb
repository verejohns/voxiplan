module Api
  class ResourcesController < Api::BaseController
    def index
      if params[:service_name]
        services = current_client.services.active.where("lower(name) = ?",params[:service_name].downcase)
        result = services.map{|serv| serv.resources.active.map {|r| {'id' => r.id, 'name' => r.name.presence || s.ename}}}
        result = result[0] if result.count > 0
      elsif params[:service_id]
        service = current_client.services.active.find_by_id(params[:service_id])
        result = service.nil? ? nil : service.resources.active.map {|r| {'id' => r.id, 'name' => r.name.presence || r.ename}}
      else
        first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
        if first_agenda.is_online_agenda?
          resources = current_client.resources.where(ivr_id: current_ivr.id, agenda_type: first_agenda.type).order(name: :asc)
        else
          resources = current_client.resources.where(ivr_id: current_ivr.id).order(is_default: :desc).order(created_at: :asc)
        end

        result = resources.active.map {|r| {'id' => r.id, 'name' => r.name.presence || r.ename}}
      end

      session[:data][:hints] = result.nil? ? [] : result.map{|r| r['name']}.compact.join(", ")
      render json: result || []
    end
  end
end