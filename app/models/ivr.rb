class Ivr < ApplicationRecord
  include UidEntity
  include InterpolationUtils
  include JSONConvertEntity
  include PhoneNumberUtils

  belongs_to :client
  has_many :nodes, dependent: :destroy, autosave: true
  belongs_to :start_node, class_name: 'Node', optional: true

  # has_many :agenda_app, :dependent => :destroy, autosave: true

  has_many :reminder, :dependent => :destroy

  has_many :calls, dependent: :destroy
  has_many :text_messages, dependent: :destroy
  has_many :tropo_webhooks, through: :calls
  has_many :conversations, dependent: :destroy
  has_many :appointments, dependent: :destroy

  has_many :resources, dependent: :destroy
  has_many :services, dependent: :destroy

  has_many :identifiers, inverse_of: :ivr, dependent: :destroy, autosave: true
  accepts_nested_attributes_for :identifiers,
                                allow_destroy: true,
                                reject_if: proc { |attributes,b| puts "******** new_record?new_record?, b: #{b}, attribte#{attributes.inspect}"; attributes['identifier'].blank? }

  has_attached_file :logo
  # validates :description, presence: true, if: :use_branding
  validates_attachment :logo, content_type: { content_type: ["image/jpg", "image/jpeg", "image/png", "image/gif"] }

  # TODO: Add validation to validate that strategy must be one of following key
  BOT_OFFER_STRATEGIES = {
    'first_available_slot' => 'We have a free slots at 11:30h, Is this fine?',
    'day_by_day' => 'Tomorrow between 9h and 17h is fine? ',
    'search_first' => 'when would you like to come?',
  }

  has_paper_trail skip: %i[updated_at]

  delegate :default_user, to: :client

  #before_create { create_agenda } # {self.agenda_app = DummyAgenda.new }
  after_save :change_static_ivr

  AUTO_MANUAL = {auto: 'auto', manual: 'manual'}
  attr_accessor :options

  def options
    @options ||= {}
  end

  def find_node(name)
    nodes.find_by(name: name)
  end

  def only_ai?
    preference['only_ai']
  end

  def play_enabled?
    preference['play_enabled']
  end

  def ai_start_node
    find_node('ai_bot_start_conversation')
  end

  before_create :set_default_voice
  after_create :create_static_ivr
  after_create :create_identifiers
  before_create :set_default_preferences

  def create_identifiers
    self.identifiers.create(identifier: "#{self.uid}@voxi.ai")
  end

  # options[:copy_text] => true
  def create_static_ivr
    start_node = StaticIvr.new(self, @options).build
    self.update_column(:start_node_id, find_node(start_node).id)
    self.preference['widget_language'] = self.try(:start_node).try(:locale_from_voice) || '-'
    self.save
  end

  def create_agenda
    ss_default_params ||= <<~EOS
      full_name=To complete
      email=to-complete@example.com
      address=To complete
      mobile=To complete
      phone=To complete
      country=BE
      description=To complete
      super_field=%{caller_id}
    EOS

    agenda = AgendaApp.new(
      type:     'DummyAgenda',
      ivr_id:      self.id,
      ss_default_params: ss_default_params,
      default_resource_availability: BusinessHours::DEFAULT_AVAILABILITY
    )
    agenda.save
    agenda
  end

  def set_default_voice
    # voices = TelephonyEngine.voices.select{|v| v[:locale] == I18n.locale.to_s}
    # voices = TelephonyEngine.voices.select{|v| v[:locale].include? I18n.locale.to_s} if voices.blank?
    voices = TelephonyEngine.voices.select{|v| v[:locale].include? I18n.locale.to_s}
    if voices
      voice = voices.find {|v| v[:voice].include? 'Wavenet'} ||
          voices.find {|v| v[:voice] == 'alice'} ||
          voices.find {|v| v[:gender] == 'Female'} ||
          voices.first
    end

    # Use google Neural female voice for all the accounts at signup
    # :voice: en-US-Neural2-F
    # :title: Vox-C, Female (Premium-Neural)
    # :gender: FEMALE
    # :locale: en-US
    # :language: English, US
    # :tts: google
    voice = TelephonyEngine.voices.select{|v| v[:locale]  == 'en-US' && v[:gender] == 'FEMALE' && v[:voice] == 'en-US-Neural2-F'}.first if voice[:locale].include? 'en'
    voice = TelephonyEngine.voices.select{|v| v[:locale]  == 'de-DE' && v[:gender] == 'FEMALE' && v[:voice] == 'de-DE-Neural2-F'}.first if voice[:locale].include? 'de'
    voice = TelephonyEngine.voices.select{|v| v[:locale]  == 'fr-FR' && v[:gender] == 'FEMALE' && v[:voice] == 'fr-FR-Neural2-C'}.first if voice[:locale].include? 'fr'
    logger.info "***************** VOICE NOT FOUND FOR LOCALE: #{I18n.locale} ************** " unless voice
    self.voice = voice ? voice[:voice] : 'en-US-Neural2-F'
    self.voice_locale = voice ? voice[:locale] : 'en-US'
    self.google_voice_locale = self.voice_locale
    self.message = voice ? voice[:voice] : 'en-US-Neural2-F'
    self.message_locale = voice ? voice[:locale] : 'en-US'
    self.preference['play_enabled'] = voice ? voice[:tts] == 'google' : false
  end

  def destroy
    self.update_column(:start_node_id, nil)
    super
  end

  def destroy_nodes
    self.update_column(:start_node_id, nil)
    nodes.destroy_all
  end

  def regenerate
    set_default_preferences
    destroy_nodes
    create_static_ivr
    self.save
  end

  def copy_and_regenerate
    nodes.update_all("name = CONCAT(name , '__old')")
    @options = {copy_text: true}
    create_static_ivr
    nodes.where("name LIKE '%__old'").delete_all
    self.save
  end

  # create unique extension names
  def next_extension
    prefix = 'extension_'
    last_ext_name = self.nodes.where('ext_prefix like ?', "#{prefix}%").pluck(:ext_prefix).max
    puts "last_ext_name: #{last_ext_name}"
    num = last_ext_name.split('_').last.to_i + 1 rescue 1
    "#{prefix}#{'%03d' % num}"
  end

  def preference_is_service?
    preference["service_or_resource"] == "Services"
  end

  def preference_is_manual?
    preference["auto_or_manual"] == Ivr::AUTO_MANUAL[:manual]
  end

  def agenda_services
    services.where(agenda_type: agenda_app.try(:type))
    # case agenda_app.try(:type)
    # when "Mobminder"
    #   services.where(agenda_type: "Mobminder")
    # when "Timify"
    #   services.where(agenda_type: "Timify")
    # when "ClassicAgenda"
    #   services.where(agenda_type: "ClassicAgenda")
    # else
    #   services.where(agenda_type: "Local")
    # end
  end

  def agenda_resources
    resources.where(agenda_type: agenda_app.try(:type))
    # case agenda_app.try(:type)
    # when "Mobminder"
    #   resources.where(agenda_type: "Mobminder")
    # when "Timify"
    #   resources.where(agenda_type: "Timify")
    # when "ClassicAgenda"
    #   resources.where(agenda_type: "ClassicAgenda")
    # else
    #   resources.where(agenda_type: "Local")
    # end
  end

  # TODO: DELETE
  # def transfer_to_users(users = nil)
  #   users = [default_user] unless users.present?
  #   addresses = []
  #   users.each do |user|
  #     addresses << user.sip
  #     addresses << user.number_to_sip if user.number.present?
  #   end
  #   addresses
  # end

  def locale_from_voice
    self.try(:start_node).try(:locale_from_voice)
  end

  def allow_new_customers?
    preference["allow_new_customers"]
  end

  def more_than_one_appointment?
    return true if preference["max_allowed_appointments"].nil?
    preference["max_allowed_appointments"] > 1
  end

  def allow_cancel_or_modify?
    preference["allow_cancel_or_modify"]
  end

  def settings=(settings)
    settings.each {|k,v| bool = str_to_boolean(v); self.preference[k] = bool.nil? ? v : bool }
  end

  # method: implict or explicit
  def update_confirmation_method(new_method: nil)
    new_method ||= preference['implicit_confirmation'] ? :implicit : :explicit

    return if options[:ai_bot]
    if new_method == :implicit
      confirmation_nodes.each{|node| node.update(tries: 1, timeout_next: node.next)}
    else
      confirmation_nodes.each{|node| node.update(tries: 2, timeout_next: 'timeout')}
    end
  end

  def confirmation_nodes
    IvrBuilder.confirmation_nodes.map{|name| find_node(name) }
  end

  def implicit_confirmation?
    preference['implicit_confirmation']
  end

  def sms_number
    preference['sms_from'].presence || client.phone_numbers.sms_enabled.first || ENV['TWILIO_DEFAULT_SMS_FROM']
  end

  def session_variables(params)
    if params[:phone] == '266696687'
      caller_id = '266696687'
      customer_id = nil
    else
      phone = phone(params[:phone])
      caller_id = caller_id(phone)

      customer = find_and_create_customer_on_agenda(phone: phone)
      customer_id = customer.id
    end

    if params[:session_id]
      if params[:maintain]
        voxi_session = VoxiSession.find_by_session_id(params[:session_id])

        if params[:service_id] && params[:resource_id]
          service = Service.find(params[:service_id])
          resource = Resource.find(params[:resource_id])

          voxi_session.update_columns(service_id: service.agenda_type == 'Mobminder' || service.agenda_type == 'Timify' ? service.eid : params[:service_id], resource_id: resource.agenda_type == 'Mobminder' || resource.agenda_type == 'Timify' ? resource.eid : params[:resource_id])
        end
        current_voxi_session_id = voxi_session.id
        caller_id = voxi_session.caller_id
        choosen_resource = voxi_session.resource_id
        choosen_service = voxi_session.service_id
        customer_id = voxi_session.customer_id
      else
        voxi_session = VoxiSession.where(ivr: self, client: client, caller_id: caller_id, customer_id: customer_id).first
        if voxi_session
          current_voxi_session_id = voxi_session.id
          voxi_session.update_columns(session_id: params[:session_id].to_s)
        else
          current_voxi_session_id = VoxiSession.create(platform: params[:platform], ivr: self, client: client, session_id: params[:session_id], caller_id: caller_id, customer_id: customer_id).id
        end
      end
    else
      voxi_session = VoxiSession.where(platform: params[:platform], ivr_id: self.id, client_id: client.id, caller_id: caller_id, customer_id: customer_id).first

      if voxi_session
        current_voxi_session_id = voxi_session.id
      else
        current_voxi_session_id = VoxiSession.create(platform: params[:platform], ivr: self, client: client, caller_id: caller_id, customer_id: customer_id).id
      end
    end

    {
      current_ivr_id: self.id,
      caller_id: caller_id,
      free_slots: {},
      existing_appointments: {},
      current_customer_id: customer_id,
      current_voxi_session_id: current_voxi_session_id,
      choosen_resource: choosen_resource,
      choosen_service: choosen_service
    }
  end

  def find_and_create_customer_on_agenda(params)
    phone = params[:phone]
    caller_id = caller_id(phone)

    first_agenda = self.client.agenda_apps.count.zero? ? DummyAgenda::new : self.client.agenda_apps.first
    customer = first_agenda.find_and_create_customer(caller_id, client.id)
    return customer if customer

    type = phone.type == :mobile ? :phone_number : :fixed_line_num

    customer = Customer.create(
      type => voxi_phone(phone),
      phone_country: phone.country,
      recorded_name_url: nil,
      client: self.client,
      phone_number: parse_phone(phone).e164,
      lang: self.voice_locale
    )

    Contact.create(
      customer_id: customer.id,
      phone: parse_phone(phone).e164,
      country: phone.country,
      client: self.client
    )

    first_agenda.create_customer_on_agenda(customer.id)
    customer
  end

  def phone(num)
    Phonelib.parse(num)
  end

  def caller_id(phone)
    return @caller_id if @caller_id
    client_country = self.client.country_code rescue nil

    @caller_id =
      if phone.valid?
        puts "****** phone #{phone} is valid for international format for #{phone.country}"
        voxi_phone(phone)
      elsif Phonelib.valid_for_country? phone, client_country
        puts "****** phone #{phone} is valid for #{client_country} "
        voxi_phone(phone, client_country)
      else
        puts "****** phone #{phone} is NOT valid for #{client_country} "
        raise "Invalid user.phone: #{phone} is not a valid number for #{client_country}."
      end
  end

  def voxi_sms?
    self.preference['sms_engin'] == 'voxi_sms'
  end

  def ai_bot_enabled?
    preference["ai_bot_enabled"]
  end

  private

  # We should use another table for ivr_settings
  def set_default_preferences
    preference['allow_new_customers'] = true
    # preference['max_allowed_appointments'] = 1
    preference['say_recorded_name'] = false
    preference['allow_cancel_or_modify'] = true
    preference['service_or_resource'] = 'Services'

    preference['voxi_sms_customer_id'] = ENV['VOXI_SMS_CUSTOMER_ID']
    preference['voxi_sms_api_key'] = ENV['VOXI_SMS_API_KEY']
    preference['sms_engin'] = 'twilio'
    preference['voice_engin'] = 'twilio'
    preference['cancel_time_offset'] = "%{1_day}"
    preference['implicit_confirmation'] = false
    preference['prefer_voicemail'] = false # do not transfer in case of errors and timeouts etc
    preference['sms_from'] = '' # do not transfer in case of errors and timeouts etc
    preference['bot_offer_strategy'] = 'first_available_slot'
    preference['shorten_urls'] = false
    preference['ai_bot_enabled'] = false
    preference['widget_tz'] = self.client.time_zone rescue '-'
    preference['widget_time_format'] = '24h'
    preference['widget_filter'] = "false"
    self.confirmation_sms = true
    # self.save
  end

  def change_static_ivr
    if preference_changed?
      update_confirmation_method if preference_changed('implicit_confirmation')
      update_resource_service_first if preference_changed('service_or_resource')
      change_bot_type if preference_changed('ai_bot_enabled')
    end
  end

  def resource_service_next_node
    service_first = preference['service_or_resource'] == 'Services'

    finish = 'agenda_group_availabilities'

    if service_first
      ['agenda_services', finish, 'agenda_resources']
    else
      ['agenda_resources', 'agenda_services', finish]
    end
  end


  def change_bot_type
    IvrBuilder.new(self).change_bot_type(ai_bot_enabled? ? :ai : :default)
  end

  def update_resource_service_first
    start, resource_next, service_next = resource_service_next_node

    nodes = self.nodes.where(name: %w[check_limit_on_create say_modified])
    nodes.update_all(next: start)

    nodes = self.nodes.where(name: %w[limit_not_reached check_existing_appointments])
    nodes.update_all(invalid_next: start)

    nodes = self.nodes.where(name: %w[check_resource_availability set_choose_resource choosen_resource])
    nodes.update_all(next: resource_next)

    node = find_node 'agenda_resources'
    node.next_nodes['disabled'] = resource_next
    node.save

    nodes = self.nodes.where(name: %w[check_service_availability set_choosen_service choosen_service])
    nodes.update_all(next: service_next)

    node = find_node 'agenda_services'
    node.next_nodes['disabled'] = service_next
    node.save
  end

  def preference_changed(key)
    preference_was[key].to_s != preference[key].to_s
  end
end
