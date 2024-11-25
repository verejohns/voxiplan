class CustomersController < ApplicationController
  require 'rake'
  require 'csv'

  include PhoneNumberUtils
  include ApplicationHelper

  before_action :set_customer, only: [:edit, :update]
  before_action :check_ory_session
  layout 'layout', only: [:index]

  def index
    @customers = current_client.customers
    @customer = Customer.new

    @customer_data = []
    @customers.each do |customer|
      personal_data = {
        'RecordID' => customer.id,
        'FirstName' => customer.first_name,
        'LastName' => customer.last_name,
        'Phone' => Phonelib.parse(customer.phone_number).e164,
        'Email' => customer.email,
        'Gender' => Customer::GENDER[customer.gender],
        'Birthday' => customer.birthday,
        'Street' => customer.street,
        'Zipcode' => customer.zipcode,
        'City' => customer.city,
        'Country' => customer.country,
        'Notes' => customer.notes,
        'Phone2' => customer.contacts.where.not(phone: customer.phone_number).first&.phone,
        'Phone3' => customer.contacts.where.not(phone: customer.phone_number).second&.phone,
        'Phone4' => customer.contacts.where.not(phone: customer.phone_number).third&.phone,
      }
      @customer_data.push(personal_data)
    end

    respond_to do |format|
      format.html
      format.csv { send_data export_csv(@customers), :type => 'text/csv;charset=utf-8; header=present', :disposition => 'attachment;filename=contacts.csv' }
    end
  rescue => e
    puts e.message
  end

  def export_csv(data)
    attributes = ["first_name", "last_name", "phone_number", "email", "gender", "birthdate", "street", "zipcode", "city", "country", "notes",
                  "phone_number1", "phone_country2", "phone_number2", "phone_country3", "phone_number3"]
    CSV.generate({headers: true, force_quotes: true}) do |csv|
      csv << attributes
      data.each do |customer|
        phone_number1 = ""
        phone_number2 = ""
        phone_number3 = ""
        phone_country2 = ""
        phone_country3 = ""
        customer.contacts.each_with_index do |contact, index|
          next if index.zero?
          phone_number1 = contact.phone if index == 1
          phone_number2 = contact.phone if index == 2
          phone_number3 = contact.phone if index == 3
          phone_country2 = contact.country if index == 2
          phone_country3 = contact.country if index == 3
        end
        birthday = Date.parse(customer.birthday).strftime("%m/%d/%Y") rescue customer.birthday
        row = [customer.first_name, customer.last_name, customer.phone_number, customer.email, customer.gender, birthday, customer.street,
               customer.zipcode, customer.city, customer.country, customer.notes, phone_number1, phone_country2, phone_number2, phone_country3, phone_number3]
        csv.add_row row
      end
    end
  end

  def create
    if params[:selected_customer_id].blank?
      is_duplicated = false
      customer_params[:phone_number].each do |phone_number|
        is_duplicated = true unless Contact.all.where(phone: phone_number).count.zero?
      end
      is_duplicated = true unless customer_params[:email].blank? || Customer.all.where(email: customer_params[:email]).count.zero?
      render json: { status: 'error', message: t('customers.already_registered') }, status: 200 and return if is_duplicated

      @customer = current_client.customers.build(customer_params)
      @customer.country = params[:user_country_code].upcase unless params[:user_country].blank?
      @customer.phone_country = customer_params[:phone_country][0]
      @customer.phone_number = customer_params[:phone_number][0]

      @customer.save
      customer_params[:phone_number].each_with_index do |phone_number, index|
        @contact = Contact.new(client_id: current_client.id, customer_id: @customer.id, phone: phone_number, country: customer_params[:phone_country][index])
        @contact.save
      end

      # @customer.contacts.update(client_id: current_client.id)
      @customers = current_client.customers
      unless @customer.created_on_agenda?
        current_client.agenda_apps.each do |agenda|
          CreateCustomerOnAgendaJob.perform_later(@customer.id, agenda.id)
        end
      end
    else
      @customer = current_client.customers.find_by(id: params[:selected_customer_id])
      is_duplicated = false
      customer_params[:phone_number].each do |phone_number|
        is_duplicated = true unless Contact.all.where(phone: phone_number).where.not(customer_id: @customer.id).count.zero?
      end
      is_duplicated = true unless customer_params[:email].blank? || Customer.all.where(email: customer_params[:email]).where.not(id: @customer.id).count.zero?
      render json: { status: 'error', message: t('customers.already_registered') }, status: 200 and return if is_duplicated

      @customer.update(customer_params)
      @customer.country = params[:user_country_code].upcase unless params[:user_country].blank?
      @customer.phone_country = customer_params[:phone_country][0]
      @customer.phone_number = customer_params[:phone_number][0]
      @customer.save
      @customer.contacts.delete_all
      customer_params[:phone_number].each_with_index do |phone_number, index|
        @contact = Contact.new(client_id: current_client.id, customer_id: @customer.id, phone: phone_number, country: customer_params[:phone_country][index])
        @contact.save
      end
      @customers = current_client.customers
    end

    render json: { status: 'success', message: t('common.save_success')}, status: 200
  rescue => e
    @customer.destroy
    render json: { status: 'failure', message: e.message }, status: 200
  end

  def edit
    render layout: false
  end

  def update
    @status = @customer.update(customer_params)
    @customers = current_client.customers
  end

  def destroy
    @customer = Customer.find(params[:id])
    @customer.destroy
    # respond_to do |format|
    #   format.html { redirect_to customers_path, notice: 'Contact was successfully destroyed.' }
    # end
    render json: {}, status: 200
  end

  def get_contact
    @customer = current_client.customers.find_by(id: params[:customer_id])
    render json: {customer_data: @customer, contact_data: @customer.contacts.count.zero? ? [{phone: @customer.phone_number, country: @customer.phone_country}] : @customer.contacts}
  end

  def send_phone_info
    Rails.application.load_tasks
    Rake::Task['migrations:phone_info_to_contacts_table'].execute
    render json: {message: 'success'}
  rescue => e
    puts e.message
    render json: {message: e.message}
  end

  def destroy_multiple
    @customers = Customer.where(id: JSON.parse(params[:ids]))
    Customer.destroy(@customers.map(&:id))

    render json: {}, status: 200
  end

  def import
    Customer.import(params[:csv_file], current_client.id) if params[:csv_file].present?
    redirect_to customers_path
  end

  def exceptions
    @customer = Customer.find(params[:customer_id])
    @customer.contacts.update_all(exceptional_number: false)
    contacts = @customer.contacts.where(id: params[:exception_list])
    contacts.update_all(exceptional_number: true)

    current_client.ivrs.each do |ivr|
      node = ivr.find_node('check_caller_id')
      exception_numbers = node.right_operand

      # normalize/reset
      # remove all contacts of this customer from exception_numbers
      exception_numbers -= exception_numbers_from(@customer.contacts)

      # just add these contacts of the customer in exception_numbers
      exception_numbers += exception_numbers_from(contacts)
      node.update!(right_operand: exception_numbers)
    end

  end

  private

  def exception_numbers_from(contacts)
    # contacts.map(&:phone)
    contacts.map{|c| voxi_phone(c.phone)}
  end

  def customer_params
  	params.require(:customer).permit!
  end

  def set_customer
  	@customer = Customer.where(client_id: current_client.id).find_by(id: params[:id])

    head :unauthorized if @customer.nil
  end
end
