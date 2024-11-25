class CheckExistingCallerJob < ApplicationJob
  queue_as :default

  def perform(agenda_app_id, caller_id, current_voxi_session_id)
    logger.error "XXXX STARTED JOB: CheckExistingCallerJob."

    agenda_app = AgendaApp.find(agenda_app_id)
    existing_caller = agenda_app.find_and_create_customer(caller_id) rescue false
    update_current_voxi_session_id(current_voxi_session_id, existing_caller)

    if existing_caller
      CheckExistingAppointmentsJob.perform_now(agenda_app_id, caller_id, current_voxi_session_id, existing_caller.id)
    end
  rescue Exception => e
    logger.error "XXXXXX Exception while CheckExistingCallerJob."
    puts e.message
    puts e.backtrace
  end

  def update_current_voxi_session_id(current_voxi_session_id, existing_caller)
    return unless current_voxi_session_id
    voxi_session = VoxiSession.find current_voxi_session_id
    if existing_caller
        voxi_session.data[:current_customer_id] = existing_caller.id
        voxi_session.data[:customer_first_name] = customer_first_name(existing_caller)
        client_type = 'returning'
    else
      client_type = 'new'
    end

    voxi_session.call.update(client_type: client_type) if voxi_session.call
    voxi_session.data[:check_existing_caller] = !!existing_caller
    voxi_session.save
  end

  def customer_first_name(customer)
    if customer.first_name.present? && customer.first_name != 'Voxiplan'
      customer.first_name
    end
  end
end
