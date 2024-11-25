class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  # before_action :configure_permitted_parameters, if: :devise_controller?
  around_action :set_time_zone
  before_action :set_locale
  before_action :set_paper_trail_whodunnit
  before_action :check_signup

  def check_signup
    redirect_to (ENV['ORY_URL'] || '') + '/self-service/registration/browser' if request.env['PATH_INFO'] == '/signup' && params["flow"].nil?
  end

  def current_client
    Client.where("ory_id = ?", session[:ory_identity].id).first if session[:ory_identity]
  rescue => e
    puts "*********** ory_client_error_application ************"
    puts e
    return nil
  end

  def get_api_instance
    OryClient.configure do |config|
      config.scheme = ENV['ORY_SCHEME']
      config.server_index = nil
      config.debugging = false
      config.api_key['oryAccessToken'] = ENV['ORY_ACCESS_TOKEN']
      config.host = ENV['ORY_PROXY_URL']
      config.base_path = ''
    end

    OryClient::FrontendApi.new
  end

  def set_time_zone
    initial_call_setup if starting_ivr
    client = current_client || client_in_ivr || client_in_widget
    if client && client.time_zone && !request.env['PATH_INFO'].include?('/s/')
      logger.info " ********* RUNNING IVR WITH ZONE:(#{client.time_zone.inspect}), Client: #{client.inspect} ******** "
      Time.use_zone(client.time_zone) {yield}
    else
      yield
    end
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      clients_path
    else
      services_path
    end
  end

  def after_sign_out_path_for(resource)
    root_path
  end

  def default_url_options
    # { locale: I18n.locale }
    { locale: cookies[:locale] || I18n.locale }
  end


  def json_to_hash(json_string)
    HashWithIndifferentAccess.new(JSON.parse(json_string))
  end

  helper_method :current_ivr, :current_admin, :current_menu

  def current_ivr
    preferred_ivr = current_client.ivrs.where(id: cookies['current_ivr_id']).take if cookies['current_ivr_id'].present?
    @current_ivr ||= (  preferred_ivr || current_client.ivrs.first)
  end

  def current_admin
    current_client if current_client && current_client.admin?
  end

  def current_menu
    menu = 'Phone'
    menu = current_client.menu_type || 'Online' if current_ivr.client.agenda_apps.count.zero? or current_ivr.client.agenda_apps.first.type == 'ClassicAgenda'
    menu
  end

  def inspect_params(p = params)
    logger.info "***************** params start ************** "
    logger.info p.to_yaml
    logger.info "***************** params end ************** "
  end

  def get_schedule_availablities schedule_id
    selected_schedule = schedule_id.zero? ? current_client.schedule_templates.where(is_default: true).first : current_client.schedule_templates.find(schedule_id)
    availability = selected_schedule.availability.availabilities
    overrides = selected_schedule.availability.overrides

    return {availabilities: availability, overrides: overrides}
  end

  protected

  def set_locale
    begin
      I18n.locale = params[:locale] || cookies[:locale] || get_browser_locale || locale_from_voice || I18n.default_locale
    rescue
      I18n.locale = I18n.default_locale
    end
  end

  def get_browser_locale
    http_accept_language.compatible_language_from(helpers.available_locales)
  end

  def check_admin!
    puts "current_client.admin?",current_client.admin?
    redirect_back fallback_location: :root, notice: 'You are not allowed to view this page.' unless current_client.is_admin?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:country, :industry, :phone, :company, :first_name, :last_name, :time_zone, :phone_country, :country_code, :preferred_locale, :server_region])

    devise_parameter_sanitizer.permit(:account_update, keys: [:country, :industry, :phone, :company, :first_name, :last_name, :time_zone, :billing_company_name, :billing_add_1, :billing_add_2, :billing_city, :billing_state, :billing_zip, :billing_country, :billing_last_name, :billing_first_name, :tax_id, :phone_country, :address_one, :address_two, :city, :state, :zip, :language, :country_code])
  end

  private

  def ivr_controller?
    params[:controller] == 'ivr'
  end

  def chat_controller?
    params[:controller] == 'chat' && ['fetch_available_slots', 'validate_customer', 'create_customer', 'book_appointment'].include?(params[:action])
  end

  def starting_ivr
    params[:id].nil? && params[:action] == 'run' && ivr_controller?
  end

  def client_in_ivr
    return unless ivr_controller?
    c = current_call.try(:ivr).try(:client) rescue nil
    c || ivr.try(:client)
  end

  def client_in_widget
    return unless chat_controller?
    c = Ivr.find(params[:ivr_id]).try(:client) rescue nil
    c || @ivr.try(:client)
  end

  def locale_from_voice
    return unless ivr_controller?
    lv = ivr.try(:locale_from_voice)
    lv[0..1] if lv.present?
  end

  def user_for_paper_trail
    current_client
  end
end
