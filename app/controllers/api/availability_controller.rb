module Api
  class AvailabilityController < Api::BaseController
    def index
      time = params[:after].present? ? Time.zone.parse(params[:after]) : Time.current

      if params[:existing_appointment_id]
        fetch_data_from_existing_appointment
      end

      if params[:service_id]
        service = current_client.services.active.find_by_id(params[:service_id])
        service_id = service&.agenda_type == 'Mobminder' || service&.agenda_type == 'Timify' ? service&.eid : service&.id
      end
      if params[:service_name]
        service = current_client.services.active.where("lower(name) = ?",params[:service_name].downcase)&.first
        service = current_client.services.active.where("lower(ename) = ?",params[:service_name].downcase)&.first unless service
        service_id = service&.agenda_type == 'Mobminder' || service&.agenda_type == 'Timify' ? service&.eid : service&.id
      end

      resource_id = params[:resource_id] if params[:resource_id]
      if params[:resource_id]
        resource = current_client.resources.active.find_by_id(params[:resource_id])
        resource_id = resource&.agenda_type == 'Mobminder' || resource&.agenda_type == 'Timify' ? resource&.eid : resource&.id
      end
      if params[:resource_name]
        resource = current_client.resources.active.where("lower(name) = ?",params[:resource_name].downcase)&.first
        resource = current_client.resources.active.where("lower(ename) = ?",params[:resource_name].downcase)&.first unless resource
        resource_id = resource&.agenda_type == 'Mobminder' || resource&.agenda_type == 'Timify' ? resource&.eid : resource&.id
      end

      data[:choosen_service] = service_id.to_s
      data[:choosen_resource] = resource_id.to_s

      error_msg = ''
      error_msg = 'Resource could not be found!' if data[:choosen_resource].blank?
      error_msg = 'Service could not be found!' if data[:choosen_service].blank?
      error_msg = 'Resource and service could not be found!' if data[:choosen_resource].blank? && data[:choosen_service].blank?

      return render json: error_msg if error_msg.present? && params[:existing_appointment_id].blank?

      constraints = {
          resource_id: data[:choosen_resource] || "",
          service_id: data[:choosen_service] || "",
          full_day: params[:full_day],
          ampm: params[:ampm],
          # time_slot: time_slot,
          weekday: Date::DAYNAMES.index(params[:weekday])
      }.compact

      if constraints['weekday']
        weekday = constraints['weekday'].to_i
        time += (1 + ((weekday - 1 - time.wday) % 7)).day if weekday
      end

      slots = client_agenda.free_slots(nil, time + 5.seconds, constraints)
      puts "************ slots **************"
      puts data
      puts constraints
      puts slots
      slots = slots.map{|s| s.slice('start', 'finish').merge('id' => store_slot_sid(s) ) }
      render json: slots
    end

    private

    def fetch_data_from_existing_appointment
      existing_appointment = data[:existing_appointments][params[:existing_appointment_id]].dup
      puts '-=-=-=-=-=-=-=-=-=-=-=-=-=Session Data for Existing Appointment-=-=-=-=-=-=-=-=-=-=-=-=-='
      puts existing_appointment.inspect
      puts '-=-=-=-=-=-=-=-=-=-=-=-=-=Session Data for Existing Appointment-=-=-=-=-=-=-=-=-=-=-=-=-='

      data[:choosen_existing_appointment_id] = existing_appointment['id']
      data[:choosen_resource] = existing_appointment['resource']
      data[:choosen_service] = existing_appointment['service']
    end

    def store_slot_sid(s)
      id = s['start'].iso8601 # SecureRandom.hex
      session[:data][:free_slots][id] = s['sid']
      id
    end

    # Will return zero padded hour 09
    def format_hour(hour)
      hour.to_s.rjust(2, "0")
    end

    def time_slot
      return nil unless params[:start_hour] || params[:end_hour]
      "#{format_hour(params[:start_hour])}#{format_hour(params[:end_hour] || '23')}"
    end

    def dummy_agenda
      dummy_agenda = DummyAgenda::new
      dummy_agenda.ivr_id = nil
      dummy_agenda.client_id = current_ivr.client.id
      dummy_agenda
    end

    def client_agenda
      agenda = agenda_app.count.zero? ? dummy_agenda : agenda_app.where('calendar_id IS NOT NULL').first
      agenda = agenda_app[0] if agenda.nil?
      agenda
    end
  end
end