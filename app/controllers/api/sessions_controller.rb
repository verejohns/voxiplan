module Api
  class SessionsController < Api::BaseController
    include PhoneNumberUtils
    skip_around_action :load_session_and_set_time_zone

    def create
      platform = params[:platform] || 'api'
      phone = params[:user] ? params[:user][:phone] || '266696687' : '266696687'
      session[:data] = nil

      session[:data] = current_ivr.session_variables(phone: phone, platform: platform, session_id: session.id)

      # TODO: DELETE
      # session[:data] = {
      #   current_ivr_id: identifier.ivr.id,
      #   caller_id: caller_id,
      #   free_slots: {},
      #   existing_appointments: {},
      #   current_customer_id: current_customer.id
      # }

      voxi_session = VoxiSession.find_by_session_id(session.id.to_s)

      json_response = {
        id: "voxi-#{session.id}",
        platform: current_voxi_session&.platform,
        caller_id: session[:data][:caller_id],
        raw_data: session[:data],
        locale: "#{voxi_session.ivr.message_locale}-#{voxi_session.client.country_code}",
        time_zone: voxi_session.client.time_zone
      }

      render json: json_response, status: :ok
    end

    def read
      session_id = params[:id].split('-').last
      voxi_session = VoxiSession.find_by_session_id(session_id)

      if voxi_session
        json_response = {
          id: "voxi-#{voxi_session.session_id}",
          platform: voxi_session.platform,
          caller_id: voxi_session.caller_id,
          ai_language: voxi_session.ivr.message_locale[0..1],
          assistant_name: voxi_session.ivr.assistant_name,
          locale: "#{voxi_session.ivr.message_locale}-#{voxi_session.client.country_code}",
          time_zone: voxi_session.client.time_zone
        }

        render json: json_response, status: :ok
      else
        Rails.cache.clear
        render json: { result: 'Could not find session with the id!' }, status: 500
      end
    rescue => e
      puts e
      render json: { result: 'error' }, status: 500
    end

    def send_email_sendgrid(to, body, subject)
      template_data = {
        title: I18n.t("mails.generic_email.title"),
        body: body,
        subject: subject,
        copyright: I18n.t("mails.copyright"),
        reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us")
      }
      options = { to: to, template_id: ENV['VOXIPLAN_EMAIL_GENERIC'], template_data: template_data }
      SendgridMailJob.set(wait: 5.seconds).perform_later SendgridMail.payload(options)
    end

    def send_email
      session_id = request.headers['X-Voxiplan-Session-ID']
      voxi_session = VoxiSession.find_by_session_id(session_id.split('-').last) if session_id

      puts "****************** voxi_session_email *****************"
      puts voxi_session

      if voxi_session
        # ClientNotifierMailer.message_email(params[:subject], params[:body], voxi_session.client.email).deliver
        send_email_sendgrid(voxi_session.client.email, params[:body], params[:subject])

        Ivr.find(voxi_session.ivr_id).resources.each do |resource|
          send_email_sendgrid(Client.find(resource.team_calendar_client_id).email, params[:body], params[:subject]) if resource.team_calendar_client_id
          # ClientNotifierMailer.message_email(params[:subject], params[:body], Client.find(resource.team_calendar_client_id).email).deliver if resource.team_calendar_client_id
        end
      end

      render json: { result: 'success' }, status: :ok
    rescue => e
      puts "*************** send_email_error ****************"
      puts e
      render json: { result: 'error' }, status: 500
    end

    private

    # TODO: DELETE, as we are using logic in ivr model
    # def current_customer
    #   customer = agenda_app.find_and_create_customer(caller_id)
    #   return customer if customer
    #
    #   type = phone.type == :mobile ? :phone_number : :fixed_line_num
    #
    #   customer = Customer.create(
    #     type => caller_id,
    #     phone_country: phone.country,
    #     recorded_name_url: nil,
    #     client: current_ivr.client,
    #     lang: current_ivr.voice_locale
    #   )
    #
    #   agenda_app.create_customer_on_agenda(customer.id)
    #   customer
    # end

    def identifier
      identifier = Identifier.find_by(identifier: params[:client_identifier])
      identifier = Identifier.find_by(identifier: params[:client_identifier] + '@voxi.ai') unless identifier

      raise AccountError, 'Could not find any account with this identifier.' unless identifier
      identifier
    end

    # def phone
    #   Phonelib.parse(params[:user][:phone])
    # end

    # def caller_id
    #   return @caller_id if @caller_id
    #   client_country = current_ivr.client.country_code rescue nil
    #
    #   @caller_id =
    #     if phone.valid?
    #       puts "****** phone #{phone} is valid for international format for #{phone.country}"
    #       voxi_phone(phone)
    #     elsif Phonelib.valid_for_country? phone, client_country
    #       puts "****** phone #{phone} is valid for #{client_country} "
    #       voxi_phone(phone, client_country)
    #     else
    #       puts "****** phone #{phone} is NOT valid for #{client_country} "
    #       raise "Invalid user.phone: #{phone} is not a valid number for #{client_country}."
    #     end
    # end
  end
end