class CreateCustomerOnAgendaJob < ApplicationJob
  queue_as :default

  def perform(customer_id, agenda_app_id)
    customer = Customer.find_by id: customer_id
    agenda_app = AgendaApp.find_by id: agenda_app_id
    return unless customer && agenda_app

    begin
      agenda_app.create_customer_on_agenda(customer.id)
      customer.update(created_on_agenda: true )
    rescue Exception => e
      logger.error "XXXXXX Exception while creating customer on Agenda #{agenda_app.id}."
      puts e.message
      puts e.backtrace
    end
  end
end
