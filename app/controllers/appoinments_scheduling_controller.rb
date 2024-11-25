class AppoinmentsSchedulingController < ApplicationController
  require 'fileutils'
  include FileUtils
  include IvrsHelper
  include SettingsHelper
  include NodeUtils
  # include InterpolationUtils
  include ApplicationHelper

  before_action :check_ory_session
  before_action :set_ivr, only: [:widget_preference, :assistant_preference, :general_preference, :save_widget_setting, :save_general_setting, :save_preferences, :save_custom_texts,
                                 :save_booking_option, :save_branding, :save_language, :save_business_hours, :save_announce, :save_welcome_message,
                                 :save_phone_menu_extentions, :delete_phone_menu_extension, :get_phone_menu_extention, :new_phone_menu_extention,
                                 :redirect_by_action, :save_menu_node, :save_selected_node, :save_phone_menu, :save_followup, :get_resources,
                                 :get_extension, :remove_extension, :save_extension]
  layout 'layout', only: [:widget_preference, :assistant_preference, :general_preference]

  def index; end


  def widget_preference
    first_agenda = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first
    redirect_to services_path and return if first_agenda.is_online_agenda?

    nodes = %w[agenda_group_availabilities]
    create_variables(@ivr, nodes)
    @widget_tz = @ivr.preference['widget_tz'] || '-'
    @widget_time_format = @ivr.preference['widget_time_format'] || '-'
    @widget_language = @ivr.preference['widget_language'] || '-'
    @widget_filter = @ivr.preference['widget_filter'] || true
    @widget_title = @ivr.preference['widget_title'] || ''
    @future_days = @ivr.preference['widget_future_days'] || ''
    @level1_dropdown = @ivr.preference["widget_level1_dropdown"] || 'Custom Order'
    @default_resource = @ivr.preference["widget_dropdown_default_resource"] || 'serviceFirst'
    @resources_list = @ivr.client.resources.where(ivr_id: @ivr.id).for_widget

    nodes = @ivr.nodes.where(name: ["appointment_menu1","appointment_menu2", "appointment_menu3", "appointment_menu4", "agenda_group_availabilities"])
    @agenda_group_availabilities = nodes.find_by_name("agenda_group_availabilities")

    if @ivr.client.agenda_apps.count.zero?
      active_services_list = @ivr.client.services.active.where(ivr_id: @ivr.id)
    else
      if @ivr.client.agenda_apps.first.type == 'ClassicAgenda'
        active_services_list = @ivr.client.services.active.where(ivr_id: @ivr.id)
      else
        active_services_list = @ivr.services.active.where(ivr_id: @ivr.id, agenda_type: @ivr.client.agenda_apps.first.type)
      end
    end

    @is_possible_resource_first = true
    active_services_list.each do |active_service|
      @is_possible_resource_first = false and break if active_service.resource_distribution == 'random' || active_service.resource_distribution == 'collective'
    end
  end

  def general_preference
    @shortened_enabled = @ivr.preference.try(:[], 'shorten_urls')
  end

  def get_resources
    render json: resource_service_dependencies(params[:resources]).map { |h| [ h["name"], h["id"]] }
  end

  def resource_service_dependencies(cur_resources)
    id = params[:id]
    agenda_app = current_client.agenda_apps.count.zero? ? DummyAgenda::new : current_client.agenda_apps.first

    if @ivr.preference_is_service?
      if agenda_app.is_online_agenda?
        resources = agenda_app.resources(service_id: id)
        new_resources = []

        if cur_resources == '' || cur_resources.count.zero?
          new_resources = resources
        else
          resources.each do |resource|
            activated = false

            cur_resources.each do |cur_resource|
              if resource["id"] == cur_resource
                activated = true
                break
              end
            end

            unless activated
              new_resources.push(resource)
            end
          end
        end

        new_resources
      else
        current_client.resources_by(service_id: id)
      end
    else
      if agenda_app.is_online_agenda?
        agenda_app.services(resource_id: id)
      else
        current_client.services_by(resource_id: id)
      end
    end
  end

  def save_widget_setting
    nodes = %w[agenda_group_availabilities]
    create_variables(@ivr, nodes)
    @ivr.preference['widget_tz'] = params['tz'].present? ? '-' : params['widget_tz']
    @ivr.preference['widget_time_format'] = params['time_format'].present? ? '-' : params['widget_time_format']
    @ivr.preference['widget_language'] = params['language'].present? ? '-' : params['widget_language']
    @ivr.preference['widget_filter'] = params['filter']
    @ivr.preference['widget_title'] = params['widget_title']
    @ivr.preference['widget_future_days'] = params['future_days']
    @ivr.preference["max_allowed_appointments"] = params["preference_limit"] == '' ? nil : params["preference_limit"].to_i
    @ivr.save
    save_after_time(params["after_time"])
  end

  def save_general_setting
    @ivr.preference["shorten_urls"] = params[:shortened_enabled] == false || params[:shortened_enabled] == "false" ? false : true
    @ivr.save
  end

  def save_booking_option
    @ivr.preference["widget_level1_dropdown"] = params['level1_dropdown']
    @ivr.preference["widget_dropdown_default_resource"] = params['dropdown_default_resource']
    @ivr.save
  end

  def save_branding
    if @ivr.update(branding_params)
      logo = params['ivr']['logo']
      unless logo.present?
      #   image_upload_path = Rails.root.join('public', "system/ivrs/logos/000/000/#{@ivr.id}/original")
      #   FileUtils.mkdir_p image_upload_path unless File.exists?(image_upload_path)
      #
      #   File.open(Rails.root.join(image_upload_path, logo.original_filename), 'wb') do |file|
      #     file.write(logo.read)
      #   end
      #   @ivr.update(logo_file_name: logo.original_filename, logo_content_type: logo.content_type, logo_file_size: logo.size(), logo_updated_at: Time.now)
      # else
        @ivr.update(logo_file_name: nil, logo_content_type: nil, logo_file_size: nil, logo_updated_at: nil) if params['is_removed_logo'] == 'yes' || params['is_removed_logo'] == '0'
      end

      render json: {message: 'success'}, status: 200
    else
      render json: {message: 'failure'}, status: 200
    end
  end

  def assistant_preference
    @subscription_plan = session[:current_organization].chargebee_subscription_plan
    @dedicated_phone_numbers = Identifier.where("ivr_id = ? AND identifier NOT LIKE ?", @ivr.id, '%voxi.ai')

    # business hours
    @business_node = @ivr.start_node
    @time_format = @ivr.preference['widget_time_format']

    # welcome message
    @chat_node = @ivr.nodes.where(name: 'welcome_open').first

    # extension
    @extensions = current_client.users

    # phone menu
    @menu_node = @ivr.nodes.where(name: "menu_open").first
    @menu_closed_node = @ivr.nodes.where(name: "menu_closed").first
    @chat_node = @menu_node

    @nodes = []
    @menu_node.choices.each  do |node|
      @nodes << @ivr.nodes.where(name: node[1]).first
    end

    @appointment_bot_exist = false
    @nodes.compact.each do |node|
      @appointment_bot_exist = true and break if node.ext_action == "ext_action_appointment_bot"
    end

    @closed_nodes = []
    @menu_closed_node.choices.each  do |node|
      @closed_nodes << @ivr.nodes.where(name: node[1]).first
    end

    @menu_node = @ivr.find_node("menu_open")
    reserved = @menu_node.choices.keys.map{|key| key.split('_')[1].to_i}
    available = [1,2,3,4,5,6,7] - reserved
    @extention_data = {
      'action_type' => t("phone_menu.new_extension"),
      'available_ext' => available,
      'available_users' => current_client.users,
      "message_before_call2"=> t('static_ivr.record_your_message'),
      'next_extension' => (params[:ext_type]=='open' ? @ivr.next_extension.last : ((@menu_node.choices.keys.max.last.to_i).to_s rescue 1))
    }

    # announce
    @announcement_open = @ivr.find_node("announcement_open")
    @announcement_closed = @ivr.find_node("announcement_closed")
    @chat_node = @announcement_open

    # follow-up
    @hangup_sms = @ivr.find_node('hangup_caller_sms')

    # preference
    nodes = %w[gather_number new_customers_not_allowed record_user_name agenda_group_availabilities
               appointment_success_record post_confirmation_reminder confirm_create]
    create_variables(@ivr, nodes)

    # custom texts
    nodes = %w[appointment_announcement_open appointment_announcement_closed select_service select_resource
              appointment_success_record appointment_success_recorded post_confirmation_reminder
              say_cancel_time_limit_reached max_appointment_limit_reached appointment_success
              confirm_cancel confirm_create appointment_menu1 appointment_menu2 appointment_menu3
            ]
    create_variables(@ivr, nodes)
    @node = @ivr.preference_is_service? ? @select_service : @select_resource

    # @schedule_templates = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc)
    # @selected_schedule = current_client.schedule_templates.where(is_default: true).first
    @customize_availability = @business_node.business_hours
    @customize_overrides = @business_node.overrides
    #
    # if @business_node.schedule_template_id.zero?
    #   # if client user 'customize hours', schedule template is default template.
    #   @selected_schedule = current_client.schedule_templates.where(is_default: true).first
    #   @selected_availability_type = 'customize'
    # else
    #   # if client user 'default hours', schedule template is selected template.
    #   @selected_schedule = current_client.schedule_templates.find(@business_node.schedule_template_id)
    #   @selected_availability_type = 'default'
    # end

    nodes = @ivr.nodes.where(name: ["appointment_menu1","appointment_menu2", "appointment_menu3", "appointment_menu4", "agenda_group_availabilities"])
    @agenda_group_availabilities = nodes.find_by_name("agenda_group_availabilities")


    language_spoken = []
    TelephonyEngine.voices.each do |item|
      # don't change "spoken", if you want to change, the string length must be 6 characters.
      # this value is stored to message_section of ivrs table.
      if (item[:locale].include? "en") || (item[:locale].include? "fr") || (item[:locale].include? "de")
        locale = item[:locale]
        locale = 'en-US' if item[:locale] == 'en'
        locale = 'de-DE' if item[:locale] == 'de'
        locale = 'fr-FR' if item[:locale] == 'fr'
        locale = 'it-IT' if item[:locale] == 'it'
        locale = 'es-ES' if item[:locale] == 'es'
        language_spoken.push({locale: locale, language: item[:language], section: 'spoken'})
      end
    end
    @language_spoken = language_spoken.uniq { |h| h[:language] }

    twilio_languages = YAML.load(File.read(File.expand_path('db/twilio_voices.yml'))).symbolize_keys[:voices]
    translate_voice_languages = []
    twilio_languages.each do |language|
      # don't change "twilio", if you want to change, the string length must be 6 characters.
      # this value is stored to message_section of ivrs table.
      locale = language[:locale]
      locale = 'en-US' if language[:locale] == 'en'
      locale = 'de-DE' if language[:locale] == 'de'
      locale = 'fr-FR' if language[:locale] == 'fr'
      locale = 'it-IT' if language[:locale] == 'it'
      locale = 'es-ES' if language[:locale] == 'es'
      translate_voice_languages.push({locale: locale, language: language[:language], section: 'twilio'}) unless (language[:locale].include? "en") || (language[:locale].include? "fr") || (language[:locale].include? "de")
    end

    if !@ivr.preference['only_ai'] && (@subscription_plan == "premium" || @subscription_plan == "trial" || @subscription_plan == "custom")
      csv_translate_languages = CSV.parse(File.read(File.expand_path('db/translate_language.csv')), headers: true)
      translate_languages = csv_translate_languages.by_col[1]
      translate_locales = csv_translate_languages.by_col[0]
      translate_languages.each_with_index do |language, index|
        # don't change "transl", if you want to change, the string length must be 6 characters.
        # this value is stored to message_section of ivrs table.
        translate_voice_languages.push({ locale: translate_locales[index], language: language.downcase.capitalize(), section: 'transl' })
      end
    end

    @translate_voice_languages = translate_voice_languages.uniq { |h| h[:language] }
    @translate_voice_languages = @translate_voice_languages.sort_by { |h| h[:language] }
  end

  def save_language
    ivr_params = {assistant_name: params[:assistant_name]}
    if params[:voice] && params[:voice][:language] && params[:client] && params[:client][:voice]
      voice = TelephonyEngine.voices.find{|v| v[:language] == params[:voice][:language] && v[:voice] == params[:client][:voice]}
      google_voice_locale = voice[:locale][0..1] + '-' + @ivr.client.country_code

      google_languages = CSV.parse(File.read(File.expand_path('db/google_language.csv')), headers: true)
      google_language_locales = google_languages.by_col[1]
      google_voice_locale = map_lang(voice[:locale]) unless google_language_locales.include? google_voice_locale

      ivr_params.merge!(voice: voice[:voice], voice_locale: voice[:locale], google_voice_locale: google_voice_locale)
    end

    if params[:message] && params[:message][:language]
      message_locale_value = params[:message][:language]
      message_section = message_locale_value[0..5]
      message_locale = message_locale_value[7..-1]
      if params[:client] && params[:client][:message]
        message = TelephonyEngine.voices.find{|v| v[:locale] == message_locale && v[:voice] == params[:client][:message]}
        message_voice =  message[:voice]
      else
        message_voice = nil
      end
      ivr_params.merge!(message: message_voice, message_locale: message_locale, message_section: message_section)
    end

    if @ivr.update(ivr_params)
      @ivr.preference['play_enabled'] = !@ivr.preference['only_ai'] && voice && voice[:tts] == 'google' || @ivr.preference['only_ai'] && message && message[:tts] == 'google'
      @ivr.save!

      if params[:message] && params[:message][:language] && params[:client] && params[:client][:message]
        nodes = @ivr.nodes.where(left_operand: "user_says")

        nodes.each do |node|
          if @ivr.assistant_name == "Laura"
            node.update_columns(right_operand: "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{message[:locale][0..1]}'}")
          else
            node.update_columns(right_operand: "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{message[:locale][0..1]}', 'assistant_name': '#{@ivr.assistant_name}'}")
          end
        end
      end

      render 'shared/save_success', layout: false, status: 200
    else
      render 'shared/save_error', layout: false, status: 422
    end
  end

  def save_business_hours
    @business_node = @ivr.start_node

    availability_hours = availabilities_hours(params[:business_hours])
    override_hours = override_hours(params[:override_hours])
    @business_node.schedule_template_id = 0
    @business_node.business_hours = availability_hours.to_json
    @business_node.overrides = override_hours.empty? ? nil : override_hours

    @business_node.save!
    render 'shared/save_success', layout: false, status: 200
  end

  def save_announce
    @announcement_open = @ivr.find_node("announcement_open")
    @announcement_closed = @ivr.find_node("announcement_closed")
    save_node(@announcement_open, params["announcement_open"])
    save_node(@announcement_closed, params["announcement_closed"])

    render 'shared/save_success', layout: false, status: 200
  end

  def save_welcome_message
    unless params[:description_open] == ""
      @welcome_open = @ivr.nodes.where(name: 'welcome_open').first
      @welcome_open.update(text: params[:description_open])
    end

    unless params[:description_closed] == ""
      @welcome_closed = @ivr.nodes.where(name: 'welcome_closed').first
      @welcome_closed.update(text: params[:description_closed])
    end

    render 'shared/save_success', layout: false, status: 200
  end

  def new_phone_menu_extention
    hours_type = params[:hours_type]
    @menu_node = @ivr.find_node("menu_open") if hours_type == 'open'
    @menu_node = @ivr.find_node("menu_closed") if hours_type == 'close'
    reserved  =  @menu_node.choices.keys.map{|key| key.split('_')[1].to_i}
    available = [1,2,3,4,5,6,7] - reserved
    @extention_data = {
      'action_type' => t("phone_menu.new_extension"),
      'available_ext' => available,
      'actions' => extension_options(@menu_node, nil),
      'available_users' => current_client.users,
      "message_before_call2"=> t('static_ivr.record_your_message'),
    }

    render json: {status: true, extension_data: @extention_data}
  end

  def get_phone_menu_extention
    ext_type = params[:ext_type]
    node_name = params[:node_name]

    @menu_node = @ivr.find_node("menu_#{ext_type}")
    reserved  =  @menu_node.choices.keys.map{|key| key.split('_')[1].to_i}
    available = [1,2,3,4,5,6,7] - reserved
    editable_node = @ivr.nodes.find_by_name(node_name)
    # to_user = current_client.users.where(sip: editable_node.to.map{|sip| sip.split(',')[0].split(':')[1]}) rescue ''
    to_user = editable_node.ext_action == 'ext_action_send_to_voicemail' ? editable_node.next_node.users : editable_node.users

    @all_nodes = @ivr.nodes.where('name like ? ', "#{editable_node.ext_prefix}%")
    transfer_node = @all_nodes.where(type: 'Transfer').first
    record_node = @all_nodes.where(type: 'Record').first

    users_data = to_user.ids.map(&:to_s) rescue ''
    transfer_timeout = transfer_node.try(:timeout)
    @extention_data = {
      'action_type' => t("phone_menu.edit_extension"),
      "number"=> @menu_node.choices.key(params[:node_name]).split('_')[1].to_i,
      "title"=> editable_node&.ext_title,
      "actions" => extension_options(@menu_node, editable_node&.ext_action),
      "action"=> editable_node&.ext_action,
      "users"=> users_data,
      "message_before_call_enabled"=> transfer_node&.text.present? ,
      "message_before_call"=> editable_node&.text.presence || t('static_ivr.your_call_being_transfer'),
      "message_before_call2"=> record_node&.text.presence || t('static_ivr.record_your_message'),
      "activate_timeout"=> (transfer_timeout.to_i>0),
      "timeout"=> transfer_timeout,
      'available_ext' => available+[@menu_node.choices.key(params[:node_name]).split('_')[1].to_i],
      'available_users' => current_client.users,
      'ai_bot_enabled' => true
    }

    render json: {status: true, extension_data: @extention_data}
  end

  def get_extension
    extension_id = params[:extension_id]
    extension = User.find(extension_id)

    nodes = get_nodes(@ivr, %w[transfer_to_agent])
    notifications = nodes.first.users.include? extension
    availabilities = render_to_string(:partial => 'services/availability_week',:locals => {:availability => extension.availability})
    render json: {result: 'success', name: extension.name, email: extension.email, phone: extension.number, country: extension.country, enable_notification: notifications, availability: availabilities}
  end

  def remove_extension
    extension_id = params[:extension_id]
    extension = User.find(extension_id)
    nodes = get_nodes(@ivr,%w[transfer_to_agent])
    nodes.first.remove_user(extension)

    extension.destroy if extension.present?
    render json: {result: 'success', message: t('common.save_success') }
  rescue => e
    render json: {result: 'error', message: e.message }
  end

  def set_default_extension
    extension_id = params[:extension_id]
    extension = User.find(extension_id)
    ActiveRecord::Base.transaction do
      current_default_extension = extension.client.default_user
      current_default_extension.nodes.each{|n| user_ids = (n.users - [current_default_extension] + [extension]).pluck(:id); n.update_users(User.where(id: user_ids))}
      current_default_extension.update!(is_default: false)
      extension.update!(is_default: true)
    end

    render json: { result: 'success', message: t('common.save_success') }
  rescue => e
    render json: { result: 'error', message: e.message }
  end

  def save_extension
    selected_extension_id = params[:selected_extension_id]
    avaialbility_hours = availabilities_hours(params[:service_hours])
    if selected_extension_id.blank?
      extension = current_client.users.new(name: params[:extension_name], email: params[:extension_email], number: params[:phone_number],
                                           country: params[:phone_country], availability: avaialbility_hours, sip: params[:extension_sip])
      extension.sip = "#{extension.uid}@voxiplan.com" if params[:extension_sip].blank?
      extension.save
      extension_id = extension.id
    else
      extension = User.find(selected_extension_id)
      extension.update_attributes(name: params[:extension_name], email: params[:extension_email], number: params[:phone_number],
                                  country: params[:phone_country], availability: avaialbility_hours, sip: params[:extension_sip])
      extension.sip = "#{extension.uid}@voxiplan.com" if params[:extension_sip].blank?
      extension.save
      extension_id = selected_extension_id
    end

    nodes = get_nodes(@ivr, %w[transfer_to_agent voice_to_email_email])
    if params[:extension_notification_value].present?
      nodes.each{|n| n.add_user(extension) }
    else
      nodes.each{|n| n.remove_user(extension) }
    end

    render json: {result: 'success', message: t('common.save_success'), extension_id: extension_id }
  rescue => e
    render json: {result: 'error', message: e.message, extension_id: extension_id }
  end

  def delete_phone_menu_extension
    @menu_node = @ivr.nodes.where(name: "menu_#{params[:ext_type]}").last
    # @extension = @ivr.nodes.where(name: params[:data][:node_name])
    node = get_node(@ivr, params[:node_name])
    if node.ext_action == 'ext_action_say_message'
      node.destroy
    elsif node.ext_action != 'ext_action_appointment_bot'
      @nodes_to_delete =  @ivr.nodes.where('name like ? OR name like ?', "#{params[:node_name].split('_transfer')[0]}%", "#{params[:node_name].split('_record')[0]}%")
      @nodes_to_delete.destroy_all
    end
    @menu_node.choices.delete(@menu_node.choices.key(params[:node_name]))
    @menu_node.save
    @extension = params[:number]
    respond_to do |format|
      format.json { render json: @extension }
    end
  end

  def save_phone_menu_extentions()
    hours_type = params[:hours_type]
    menu_node = @ivr.nodes.where(name: "menu_open").first if hours_type == 'open'
    menu_node = @ivr.nodes.where(name: "menu_closed").first if hours_type == 'close'

    key = "key_#{params[:extension][:number]}"
    action = params[:extension][:action]

    old_node = decide_old_key(key, menu_node, action)

    return redirect_by_action(key, menu_node, action, old_node) if
      (%w[ext_action_appointment_bot ext_action_say_message].include? action)

    ext_nodes, extension_node = save_menu_node(key, menu_node)

    save_selected_node(extension_node, ext_nodes)

    # redirect_to manage_extentions_settings_path
    redirect_to assistant_preference_appoinments_scheduling_index_path(@ivr.id)
  end

  def decide_old_key(key, menu_node, action)
    old_key = params[:previous_ext].blank? ? nil : "key_#{params[:previous_ext]}"
    return nil unless old_key
    old_node = @ivr.find_node(menu_node.choices.delete(old_key))
    if action != 'ext_action_say_message' && old_node.ext_action == 'ext_action_say_message'
      # Delete orphan say node
      old_node.destroy
    elsif
      menu_node.choices[key] = old_node.name
    end
    old_node
  end

  def redirect_by_action(key, menu_node, action, old_node)
    case action
    when 'ext_action_appointment_bot'
      # ai_bot_enabled = params[:extension][:ai_bot]
      menu_node.choices[key] = AppointmentBot::START
      menu_node.save

      ext_nodes = @ivr.nodes.where('name = ? ', (AppointmentBot::START).to_s).first
      ext_nodes.ext_title = params[:extension][:title]
      ext_nodes.save

      redirect_to assistant_preference_appoinments_scheduling_index_path(@ivr.id) and return

    when 'ext_action_say_message'
      if old_node && old_node.ext_action == 'ext_action_say_message'
        say_ext = old_node
      else
        say_ext = Say.create(name: @ivr.next_extension, ivr: @ivr,
                             ext_action: 'ext_action_say_message',
                             ext_title: params[:extension][:title],
                             ext_prefix: @ivr.next_extension,
                             next: menu_node.name)
      end

      say_ext.update(text: params[:extension][:message_before_call])
      menu_node.choices[key] = say_ext.name
      menu_node.save
      redirect_to assistant_preference_appoinments_scheduling_index_path(@ivr.id) and return
    end
  end

  def save_menu_node(key, menu_node)
    if menu_node.choices[key] == nil
      transfer_extension = TransferExtension.new(@ivr, prefix: @ivr.next_extension, title: "Extension #{params[:extension][:number]}").build
    else
      transfer_extension = menu_node.choices[key]
    end

    new_extension = @ivr.nodes.where(name: transfer_extension).first
    ext_nodes = @ivr.nodes.where('name like ? ', "#{new_extension.ext_prefix}%")
    extension_node = ext_nodes.find_by_ext_action(params[:extension][:action])
    menu_node.choices[key] = extension_node.name
    menu_node.save
    [ext_nodes, extension_node]
  end

  def save_selected_node(extension_node, ext_nodes)
    users = current_client.users.where(id: params[:extension][:users])
    # set email of user
    ext_nodes.where(type: 'SendEmail').each{|n| n.update_users(users) }

    selected_node = @ivr.nodes.find_by(name: extension_node.name) # we can save 1 query as extension_node is already there
    selected_node.update_users(users)
    text = params[:extension][:message_before_call_enabled] == "on" ? params[:extension][:message_before_call] : ""
    selected_node.text = text
    # selected_node.enabled = ((params[:extension][:message_before_call_enabled] == "on") ? true : false)
    selected_node.ext_title =  params[:extension][:title] if params[:extension][:title]
    selected_node.save

    ext_nodes.where(type: 'Transfer').each{|n| n.update(timeout: params[:extension][:time_out])} unless params[:extension][:time_out] == '0'
    ext_nodes.where(type: 'Record').each{|n| n.update(text: params[:extension][:message_before_call2])}

  end

  def save_phone_menu
    @ivr.preference["ai_bot_enabled"] = params["enable_ai_bot_value"] == "true" ? true : false
    @ivr.save
    @menu_node = @ivr.nodes.where(name: "menu_open").first
    @menu_closed_node = @ivr.nodes.where(name: "menu_closed").first
    begin
      if (open_params = params[:announcement][:open])
        save_node(@menu_node, open_params)
      end
      if (closed_params = params[:announcement][:closed])
        save_node(@menu_closed_node, closed_params)
      end

      render 'shared/save_success', layout: false, status: 200
    rescue
      render 'shared/save_error', layout: false, status: 422
    end
  end

  def save_followup
    @hangup_sms = @ivr.find_node('hangup_caller_sms')
    save_node(@hangup_sms, params["hangup_sms"])
    render 'shared/save_success', layout: false, status: 200
  end

  def save_preferences
    nodes = %w[gather_number new_customers_not_allowed record_user_name agenda_group_availabilities
               appointment_success_record post_confirmation_reminder confirm_create]
    create_variables(@ivr, nodes)

    @gather_number.update(enabled: params[:gather_number].present?)
    @appointment_success_record.update(enabled: params[:appointment_success_record].present?)
    @post_confirmation_reminder.update(enabled: params[:post_confirmation_reminder].present?)
    @confirm_create.update(enabled: params[:confirm_create].present?)

    @ivr.preference["allow_new_customers"] = params["allow_new_customers"].present?
    @ivr.preference["allow_cancel_or_modify"] = params["preference"]["allow_cancel_or_modify"].present?
    @ivr.preference["cancel_time_offset"] = ("%{" + params["cancel_time_offset"] + "}") if params["preference"]["allow_cancel_or_modify"].present?
    @ivr.preference["max_allowed_appointments"] = (params["kt_allow_customers_to_schedule_up"].present? ? params["preference"]["limit"] : 888873).to_i
    @ivr.preference["implicit_confirmation"] = (params["preference"]["implicit_confirmation"] == "true")
    @ivr.save
    save_after_time(params["prevent_customer"] ? params["after_time"] : "0_day")

    render 'shared/save_success', layout: false, status: 200
  end

  def save_custom_texts
    nodes = %w[appointment_announcement_open appointment_announcement_closed select_service select_resource
              appointment_success_record appointment_success_recorded post_confirmation_reminder
              say_cancel_time_limit_reached max_appointment_limit_reached appointment_success
              confirm_cancel confirm_create appointment_menu1 appointment_menu2 appointment_menu3
            ]
    create_variables(@ivr, nodes)
    @node = @ivr.preference_is_service? ? @select_service : @select_resource
    save_node(@appointment_announcement_open, params[:appointment_announcement_open])
    save_node(@appointment_announcement_closed, params[:appointment_announcement_closed])
    if current_client.is_admin?
      save_node(@node, params.require(:node))
      save_node_text(@appointment_menu1, params[:appointment_menu1])
      save_node_text(@appointment_menu2, params[:appointment_menu2])
      save_node_text(@appointment_menu3, params[:appointment_menu3])
      save_node_text(@appointment_success, params[:appointment_success])
      save_node_text(@confirm_cancel, params[:confirm_cancel])
      save_node(@confirm_create, params[:confirm_create])
    end
    params[:appointment_success_recorded][:enabled] = params[:appointment_success_record][:enabled]
    save_node(@appointment_success_record, params[:appointment_success_record])
    save_node(@appointment_success_recorded, params[:appointment_success_recorded])
    save_node(@post_confirmation_reminder, params[:post_confirmation_reminder])
    save_node_text(@say_cancel_time_limit_reached, params[:say_cancel_time_limit_reached])
    save_node_text(@max_appointment_limit_reached, params[:max_appointment_limit_reached])
    render 'shared/save_success', layout: false, status: 200
  end


  private

  def set_ivr
    @ivr = Ivr.find(params[:ivr_id])
  end

  def branding_params
    params.require(:ivr).permit(:remove_voxiplan_branding, :use_branding, :logo, :description)
  end

  def save_preference(data, cancel_time_offset)
    data = data || {}
    @ivr.preference["allow_cancel_or_modifyfcancel_time_offset"] = data["allow_cancel_or_modify"] == "true"
    max_app = data["more_than_one_appointment"] == "true" ? (data["limit"].to_i == 0 ? nil : data["limit"].to_i) : 1
    @ivr.preference["max_allowed_appointments"] = max_app
    @ivr.preference["cancel_time_offset"] = "%{" + cancel_time_offset + "}"
    @ivr.save
    flash[:success] = "Your changes were saved!"
  end

  def save_after_time data
    @agenda_group_availabilities.parameters["after_time"] = "%{" + data + "}"
    @agenda_group_availabilities.save
  end

  # https://cloud.google.com/speech-to-text/docs/languages
  def map_lang(lang)
    case lang
    when 'en'
      'en-US'
    when 'fr'
      'fr-FR'
    when 'de'
      'de-DE'
    when 'it'
      'it-IT'
    when 'es'
      'es-ES'
    else
      lang
    end
  end

  def extension_params
    params.require(:user).permit(:name, :email, :number, :sip, :country)
  end
end
