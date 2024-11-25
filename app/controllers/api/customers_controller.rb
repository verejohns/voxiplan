module Api
  class CustomersController < Api::BaseController
    # return existing appointments
    def index
      render json: current_client.customers
    end

    def auth_consumer
      params[:phone] = Phonelib.parse(params[:phone]).e164 if params[:phone]
      customer1 = nil
      agenda_app1 = nil
      customer = current_client.customers.find_by(phone_number: params[:phone])
      contact = current_client.contacts.find_by(phone: params[:phone])
      contact = current_client.customers.find{ |n| n.contacts.find_by(phone: params[:phone])} if contact.blank?
      current_client.ivrs.each do |ivr|
        customer1 = client_agenda_ivr(ivr).find_customer(phone: params[:phone], client_id: current_client.id) if (customer || contact || customer1).blank?
        agenda_app1 = client_agenda_ivr(ivr) if agenda_app1.blank?
      end
      if customer1.present?
        customer = current_client.customers.create(first_name: customer1["firstname"], last_name: customer1["lastname"], gender: customer1["gender"],
                                                   phone_number: Phonelib.parse(customer1["mobile"]).e164, fixed_line_num: customer1["phone"], email: customer1["email"])
        customer.contacts.create(client_id: current_client.id, phone: Phonelib.parse(customer1["mobile"]).e164)
        create_customer(customer.id, agenda_app1.id) unless customer.created_on_agenda?
      end
      customer_id = customer&.id.presence || contact&.customer&.id
      data[:current_customer_id] = customer_id

      id = request.headers['X-Voxiplan-Session-ID'] || request.env['X-Voxiplan-Session-ID']
      voxi_session = VoxiSession.find_by_session_id(id.split('-').last) if id
      voxi_session.update_columns(customer_id: customer_id)

      render json: { authourized: customer_id.present? }
    end

    def create
      customer = Customer.where(phone_number: Phonelib.parse(params[:contacts_attributes][0][:phone]).e164, client_id: current_client.id).first

      if customer
        customer.update(first_name: params[:customer][:first_name], last_name: params[:customer][:last_name], email: params[:customer][:email],
                                gender: params[:customer][:gender], birthday: params[:customer][:birthday], city: params[:customer][:city],
                                street: params[:customer][:street], zipcode: params[:customer][:zipcode], notes: params[:customer][:notes])
      else
        customer = Customer.create(first_name: params[:customer][:first_name], last_name: params[:customer][:last_name], email: params[:customer][:email],
                                   gender: params[:customer][:gender], birthday: params[:customer][:birthday], city: params[:customer][:city],
                                   street: params[:customer][:street], zipcode: params[:customer][:zipcode], notes: params[:customer][:notes],
                                   client_id: current_client.id)
      end

      if customer.save
        unless params[:contacts_attributes].count.zero?
          customer.update_columns(phone_number: Phonelib.parse(params[:contacts_attributes][0][:phone]).e164, eid: customer.id)

          params[:contacts_attributes].each_with_index do |contact, index|
            new_contact = Contact.create(customer_id: customer.id, phone: Phonelib.parse(contact[:phone]).e164, country: contact[:country], client_id: current_client.id)
            customer.update_columns(phone_country: new_contact.country) if index.zero?
          end
        end

        create_customer(customer.id, client_agenda.id) unless customer.created_on_agenda?

        id = request.headers['X-Voxiplan-Session-ID'] || request.env['X-Voxiplan-Session-ID']
        voxi_session = VoxiSession.find_by_session_id(id.split('-').last) if id
        voxi_session.update_columns(customer_id: customer.id)

        render json: customer.to_json(:include => [:contacts]) , status: :created
      else
        render json: customer.errors, status: :unprocessable_entity
      end
    rescue => e
      puts e
      render json: { result: "Invalid Birthday Format" }, status: 500
    end

    private

    def create_customer(customer_id, agenda_id)
      customer = Customer.find_by id: customer_id
      agenda_app = AgendaApp.find_by id: agenda_id
      return unless customer && agenda_app

      begin
        agenda_app.create_customer_on_agenda(customer.id)
        customer.update(created_on_agenda: true )
      rescue Exception => e
        logger.error "XXXXXX Exception while creating customer on Agenda #{agenda_app.id}."
        puts e.message
        puts e.backtrace
        raise e.message
      end
    end

    def customer_params
      params[:customer].permit(:first_name ,:last_name ,:email ,:gender ,:birthday ,:city ,:street ,:zipcode ,:notes, contacts_attributes: [:phone, :country])
    end

    def dummy_agenda
      dummy_agenda = DummyAgenda::new
      dummy_agenda.ivr_id = current_ivr.id
      dummy_agenda.client_id = current_ivr.client.id
      dummy_agenda
    end

    def client_agenda
      agenda = agenda_app.count.zero? ? dummy_agenda : agenda_app.first
      agenda
    end

    def dummy_agenda_ivr(ivr)
      dummy_agenda = DummyAgenda::new
      dummy_agenda.ivr_id = ivr.id
      dummy_agenda.client_id = ivr.client.id
      dummy_agenda
    end

    def client_agenda_ivr(ivr)
      agenda = ivr.client.agenda_apps.count.zero? ? dummy_agenda_ivr(ivr) : ivr.client.agenda_apps.where('calendar_id IS NOT NULL').first
      agenda = ivr.client.agenda_apps.first if agenda.nil?
      agenda
    end
  end
end