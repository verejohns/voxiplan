module Api
  class PreferencesController < Api::BaseController
    def index
      render json: preferences, status: 200
    end

    private
    def preferences
      if params[:existing_caller]
        CheckExistingCallerJob.perform_now(agenda_app.id, data[:caller_id], current_voxi_session.id)
        preferences[:existing_caller] = data[:check_existing_caller]
      end

      preferences = {}
      # key return as
      keys =
        {
          allow_cancel_or_modify: 'allow_cancel_or_modify',
          max_allowed_appointments: 'max_allowed_appointments',
          service_or_resource: 'first_offer_service_or_resource',
          bot_offer_strategy:  'bot_offer_strategy'
        }

      keys.each do |k,v|
        preferences[v] = current_ivr.preference[k.to_s]
      end

      preferences[:allow_cancel_before_minutes] = time_offset(current_ivr.preference['cancel_time_offset'])/60
      # preferences[:bot_offer_strategy] = 'search_first'
      # preferences[:time_format] = '%A, %d %B, %Y at %I:%MScheduling concepts %p'

      preferences[:templates] = {
        utter_greet: [
          { text: 'Hi, I am Laura your virtual assistant. I can schedule appointments for you.' }
        ],
        utter_goodbye: [
          { text: 'Goodbye!' }
        ],
        utter_verify_selected_service: [
          { text: 'You selected {selected_service}, Is this right?' }
        ],
      }

      set_resource_service(preferences) if params[:resource_service]

      preferences[:timezone] = current_ivr.client.time_zone
      preferences[:existing_appointments] = data[:existing_appointments_result] ? data[:existing_appointments_result] : nil
      preferences[:address] = current_ivr.client.full_address
      preferences[:platform] = current_voxi_session&.platform
      preferences[:record_message_after_appointment] = current_ivr.find_node('appointment_success_record').enabled?
      preferences[:client_contry_code] = current_ivr.client.country_code
      agenda_app = current_ivr.client.agenda_apps.count.zero? ? DummyAgenda::new : current_ivr.client.agenda_apps.first
      preferences[:agenda_app] = agenda_app.type

      preferences[:caller_id] = data[:caller_id]
      preferences[:callee_number] = data[:callee_number]
      preferences[:locale] = current_ivr.voice_locale + '-' + current_ivr.client.country_code rescue 'en'
      # preferences[:raw_data] = data


      preferences
    end

    def time_offset(key)
      result = key.scan(/(\d+)_(minute|hour|day)S*/i)
      return 0 unless result.present?
      duration, method = result.first
      duration.to_i.send(method)
    end

    def set_resource_service(preferences)
      # INFO: Considered service_first
      agenda_app = current_ivr.client.agenda_apps.count.zero? ? DummyAgenda::new : current_ivr.client.agenda_apps.first
      services = agenda_app.active_services
      preferences[:services] = services

      if services.count == 1
        resources = agenda_app.active_resources(service_id: services[0]['id'])
        preferences[:resources] = resources
      end
    end

  end
end