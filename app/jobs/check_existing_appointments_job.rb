class CheckExistingAppointmentsJob < ApplicationJob
  queue_as :default

  def perform(agenda_app_id, caller_id, current_voxi_session_id, customer_id)
    logger.error "XXXX STARTED JOB: CheckExistingAppointmentsJob."
    begin
      current_customer = Customer.find customer_id
      agenda_app = AgendaApp.find(agenda_app_id)
      begin
        c_id = (agenda_app.ivr.resources.pluck(:calendar_id) << agenda_app.default_resource_calendar).uniq.compact
      rescue Exception => e
        puts e
        c_id = nil
      end

      # set @current_voxi_session
      current_voxi_session(current_voxi_session_id)
      params = {agenda_customer_id: current_customer.eid}
      params.merge!(calendar_ids: c_id) if agenda_app.type == 'ClassicAgenda' && c_id

      appointments = agenda_app.existing_appointments(params)
      appointments = appointments.map{|s| s.merge('id' => store_existing_appointment(s) ) }
      current_voxi_session.data[:existing_appointments_result] = appointments.presence || []
      current_voxi_session.save
    rescue Exception => e
      logger.error "XXXXXX Exception while CheckExistingCallerJob."
      puts e.message
      puts e.backtrace
    end
  end

  def current_voxi_session(current_voxi_session_id = nil)
    return @current_voxi_session if @current_voxi_session

    @current_voxi_session = VoxiSession.find current_voxi_session_id
  end

  def store_existing_appointment(attr)
    current_voxi_session.data[:existing_appointments] ||= {}
    id = attr['time'].iso8601 # SecureRandom.hex
    current_voxi_session.data[:existing_appointments][id] = attr
    id
  end
end
