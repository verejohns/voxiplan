class ClientsController < ApplicationController
  include ApplicationHelper

  skip_before_action :verify_authenticity_token
  before_action :check_ory_session
  # TODO: Add authorization
  before_action :check_admin!, except: [:agenda_sign_up, :billing, :change_menu, :update_gtm_trigger]
  before_action :set_client, only: %i[show, edit, update, destroy, billing, change_menu, update_gtm_trigger]
  layout 'layout', only: [:index, :phone, :billing]

  def agenda_sign_up
    agenda_sign_up_params = params.require(:client).permit(agenda_sign_up_fields: [:ss_account])
    current_client.create_agenda(agenda_sign_up_params)
    redirect_to :try_agenda_clients
  end

  # GET /clients
  def index
    @clients = Client.all
  end

  # GET /clients/1
  def show
    @ivrs = @client.ivrs
  end

  # GET /clients/new
  def new
    @client = Client.new
    @client.create_agenda
  end

  # GET /clients/1/edit
  def edit
  end

  def my_ivrs
    render json: Client.find(params[:id]).try(:ivrs)
  end

  def get_client_detail
    client_id = params[:client_id]
    client = Client.find(client_id)
    render json: {client: client}
  end

  def phone
    twilioclient = Twilio::REST::Client.new(ENV['ACCOUNT_SID'], ENV['AUTH_TOKEN'])

    @incoming_phone_numbers = twilioclient.incoming_phone_numbers.list
    puts "*************************** @incoming_phone_numbers **************************************"
    @incoming_phone_numbers.each do |incoming_phone_number|
      puts incoming_phone_number.phone_number
      puts incoming_phone_number.status_callback.nil? || incoming_phone_number.status_callback == ""
    end

    if request.post?
      if params[:removed].present?
        @identifier = Identifier.find(params[:id])
        @identifier.delete
        render json: {result: 'success', message: 'Removed successfully'}
      end
      if params[:save_assign].present?
        @identifier = Ivr.find(params[:assigned_ivr]).identifiers.new
        @identifier.identifier = params[:twilio_identifier]
        @identifier.phone_type = params[:phone_type]
        @identifier.phone_price = params[:phone_price]
        @identifier.save
        render json: {result: 'success', message: 'The selected client assigned successfully'}
      end
      begin
        if params[:server_type] == 'voice'
          TwilioEngine.update_num_url(params[:sid], voice_url: params[:server_http] + params[:server_url])
          TwilioEngine.update_num_url(params[:sid], voice_fallback_url: params[:fallback_url].blank? ? '' : params[:fallback_http] + params[:fallback_url])
          TwilioEngine.update_num_url(params[:sid], status_callback: params[:status_callback_url].blank? ? '' : params[:status_callback_http] + params[:status_callback_url])
          render json: {result: 'success', message: 'Your setting updated successfully'}
        end
        if params[:server_type] == 'sms'
          TwilioEngine.update_num_url(params[:sid], sms_url: params[:server_http] + params[:server_url])
          TwilioEngine.update_num_url(params[:sid], sms_fallback_url: params[:fallback_url].blank? ? '' : params[:fallback_http] + params[:fallback_url])
          render json: {result: 'success', message: 'Your setting updated successfully'}
        end
      rescue => e
        if e.message.include? "SmsFallbackUrl"
           err = "SMS Fall Back URl is invalid!"
        end
        if e.message.include? "VoiceFallbackUrl"
           err = "Voice Fall Back URl is invalid!"
        end
        if e.message.include? "SmsUrl"
           err = "SMS URl is invalid!"
        end
        if e.message.include? "VoiceUrl"
           err = "Voice URl is invalid!"
        end
        render json: {result: 'error', message: err}
      end
    end
  rescue => e
    puts e.message
    @incoming_phone_numbers = e.message
  end

  # POST /clients
  def create
    @client = Client.new(client_params)

    respond_to do |format|
      if @client.save
        format.html { redirect_to @client, notice: 'Client was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  # PATCH/PUT /clients/1
  def update
    respond_to do |format|
      if @client.update(client_params)
        format.html { redirect_back fallback_location: @client, notice: 'Client was successfully updated.' }
      else
        format.html { render :edit }
      end
    end
  end

  # DELETE /clients/1
  def destroy
    destroy_account = Client.find(params[:id])

    if destroy_account && destroy_account != current_client
      response = HTTParty.delete(ENV['ORY_SDK_KETO_URL'] + "/admin/identities/" + destroy_account.ory_id, {headers: { 'Authorization' => 'Bearer ' + ENV['ORY_ACCESS_TOKEN'] } })
      puts '-----------ory identify removed---------------'
      puts response

      organization = Organization.find_by_client_id(destroy_account.id)
      if organization
        invitations = Invitation.where(organization_id: organization.id, status: "accepted")
        invitations.each do |invitation|
          client = Client.find_by_email(invitation.to_email)
          deleteRelationTuple("/organization-" + session[:current_organization].id.to_s, "member", "client-" + client.id.to_s)
        end
        invitations.destroy_all

        ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
        result = ChargeBee::Subscription.cancel_for_items(organization.chargebee_subscription_id,{
          :end_of_term => true
        })
        puts result

        organization.destroy
      end

      invitations = Invitation.where(status: "accepted", to_email: destroy_account.email)
      invitations.each do |invitation|
        deleteRelationTuple("/organization-" + invitation.organization_id, "member", "client-" + destroy_account.id.to_s)
      end
      invitations.destroy_all

      if organization && destroy_account
        deleteRelationTuple("/organization-" + organization.id.to_s, "owner", "client-" + destroy_account.id.to_s)
        deleteRelationTupleSet("/organization-" + organization.id.to_s, "manage", "/organization-" + organization.id.to_s, "owner")
        deleteRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/organization-" + organization.id.to_s, "owner")
        deleteRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/app", "super-admin")
        if organization.chargebee_subscription_plan
          deleteRelationTupleSet("/app", organization.chargebee_subscription_plan, "/organization-" + organization.id.to_s, "owner")
          deleteRelationTupleSet("/app", organization.chargebee_subscription_plan, "/organization-" + organization.id.to_s, "member")
        else
          deleteRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "owner")
          deleteRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "member")
        end
        deleteRelationTupleSet("/app", "all", "/organization-" + organization.id.to_s, "owner")
        deleteRelationTupleSet("/organization-" + organization.id.to_s + "/billing", "manage", "/organization-" + organization.id.to_s, "owner")
      end

      destroy_account.ivrs.each do |ivr|
        VoxiSession.where(ivr_id: ivr.id).destroy_all
        AgendaApp.where(ivr_id: ivr.id).destroy_all
      end

      destroy_account.destroy
    end

    respond_to do |format|
      format.html { redirect_to clients_url, notice: 'Client was successfully destroyed.' }
    end
  rescue => e
    puts e
    redirect_to clients_url, notice: e.message
  end

  def billing
    redirect_to root_path, alert: "We can't get your account by unknown reason. Please try again with Sign Out/In." and return if session[:current_organization].nil? || session[:current_organization].id.nil? || current_client.nil? || current_client.id.nil?
    redirect_to request.env["HTTP_REFERER"] and return unless checkRelationTuple("/organization-" + session[:current_organization].id.to_s + "/billing", "manage", "client-" + current_client.id.to_s)

    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    result = ChargeBee::Subscription.retrieve(session[:current_organization].chargebee_subscription_id)
    subscription = result.subscription

    if subscription.subscription_items.count.zero?
      @subscription_plan = 'free'
    else
      subscription.subscription_items.each do |subscription_item|
        @subscription_plan = ''
        @subscription_plan = 'free' if subscription_item.item_price_id == ENV['FREE_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['FREE_MONTHLY_EUR_ID']
        @subscription_plan = 'trial' if subscription_item.item_price_id == ENV['PREMIUM_TRIAL_USD_ID'] || subscription_item.item_price_id == ENV['PREMIUM_TRIAL_EUR_ID']
        @subscription_plan = 'basic' if subscription_item.item_price_id == ENV['BASIC_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['BASIC_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['BASIC_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['BASIC_YEARLY_EUR_ID']
        @subscription_plan = 'premium' if subscription_item.item_price_id == ENV['PREMIUM_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['PREMIUM_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['PREMIUM_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['PREMIUM_YEARLY_EUR_ID']
        @subscription_plan = 'custom' if subscription_item.item_price_id == ENV['CUSTOM_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['CUSTOM_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['CUSTOM_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['CUSTOM_YEARLY_EUR_ID']
        break unless @subscription_plan.blank?
      end
    end

    current_client.organizations.update_all(chargebee_subscription_plan: @subscription_plan)
    session[:current_organization] = current_client.organizations.first

    redirect_to aggregates_reports_path and return if @subscription_plan == "basic" || @subscription_plan == "premium" || @subscription_plan == "custom"

    @trial_end_date = DateTime.parse((session[:current_organization].created_at + 14.days).to_s).strftime("%B %d, %Y")
    if request.post?
      ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])

      subscription_id = session[:current_organization].chargebee_subscription_id
      item_price_id = ''
      seat_price_id = ''
      membership_plan = params[:membership_plan]

      if params[:membership_period] == 'monthly'
        item_price_id = ENV["FREE_MONTHLY_#{current_client.currency_code}_ID"] if membership_plan == 'free'
        item_price_id = ENV["BASIC_MONTHLY_#{current_client.currency_code}_ID"] if membership_plan == 'basic'
        item_price_id = ENV["PREMIUM_MONTHLY_#{current_client.currency_code}_ID"] if membership_plan == 'premium'
        item_price_id = ENV["CUSTOM_MONTHLY_#{current_client.currency_code}_ID"] if membership_plan == 'custom'
        seat_price_id = ENV["SEAT_MONTHLY_#{current_client.currency_code}_ID"]
      end
      if params[:membership_period] == 'annually'
        item_price_id = ENV["FREE_YEARLY_#{current_client.currency_code}_ID"] if membership_plan == 'free'
        item_price_id = ENV["BASIC_YEARLY_#{current_client.currency_code}_ID"] if membership_plan == 'basic'
        item_price_id = ENV["PREMIUM_YEARLY_#{current_client.currency_code}_ID"] if membership_plan == 'premium'
        item_price_id = ENV["CUSTOM_YEARLY_#{current_client.currency_code}_ID"] if membership_plan == 'custom'
        seat_price_id = ENV["SEAT_YEARLY_#{current_client.currency_code}_ID"]
      end

      appointment_price_id = ENV["APPOINTMENT_#{current_client.currency_code}_ID"]
      task_price_id = ENV["TASK_#{current_client.currency_code}_ID"]

      if membership_plan == 'free'
        result = ChargeBee::HostedPage.checkout_existing_for_items({
                   :subscription => {:id => subscription_id },
                   :subscription_items => [{ :item_price_id => item_price_id, :quantity => 1}],
                   :redirect_url => aggregates_reports_path(),
                   :embed => false
                 })
      else
        result = ChargeBee::HostedPage.checkout_existing_for_items({
                                                                     :subscription => {:id => subscription_id },
                                                                     :subscription_items => [{ :item_price_id => item_price_id, :quantity => params[:seat_nums].to_i } ],
                                                                     :redirect_url => aggregates_reports_url,
                                                                     :embed => false
                                                                   })
      end

      render :json => result.hosted_page.to_s
    end
  end

  def edit_text
  end

  def change_menu
    if request.post?
      @client.menu_type = params["menu_type"]
      @client.save
      render json: {message: 'Your changes were saved!'}, status: 200
    end
  end

  def update_gtm_trigger
    if request.post?
      @client.gtm_triggered = true
      @client.save
      render json: {message: 'Your changes were saved!'}, status: 200
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_client
    @client = Client.where(id: params[:id]).take if current_client.admin?
    @client ||= current_client
  end

  # TODO: Delete. No longer used
  # def create_summary(start_date, end_date)
  #   @client ||= current_client
  #   @report = {}
  #   # TODO: Delete. Appointments are now associated to calls instead of client
  #   @report[:total_confirmed_appointments] = @client.appointments.between(start_date, end_date).count
  #   @report[:total_incoming_calls] = @payloads.calls.in.count
  #   @report[:total_incoming_calls_minutes] = @payloads.calls.in.duration_in_minutes
  #   @report[:total_outgoing_calls] = @payloads.calls.out.count
  #   @report[:total_outgoing_calls_minutes] = @payloads.calls.out.duration_in_minutes
  #   @report[:total_sms] = @payloads.sms_count
  # end

  # Never trust parameters from the scary internet, only allow the white list through.
  def client_params
    params.require(:client).permit(:first_name, :last_name, :country, :email, :phone, :sip, :agent_number, :schedule_id, :checksum, :voice,
                                   :default_params, :confirmation_sms, :preferred_locale, :identifier,
                                   ivr_text: [:welcome, :menu1, :menu2, :menu3, :ask_phone, :appointment_success,
                                              :appointment_error, :sms_text, :transferring_call, :incorrect_option],
                                   :agenda_app_attributes => agenda_attributes)
  end

  def agenda_attributes
    [:type, :ss_schedule_id, :ss_checksum,:ss_default_params, :mm_login, :mm_pwd, :mm_kid, :id]
  end


end
