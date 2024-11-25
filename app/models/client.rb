class Client < ApplicationRecord
  rolify
  include UidEntity
  include PhoneNumberUtils
  include JSONConvertEntity
  include ApplicationHelper

  has_many :agenda_apps, dependent: :destroy
  has_many :ivrs, dependent: :destroy
  has_many :billings, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :payment_details
  has_many :subscription, dependent: :destroy
  has_one :webhook_call_detail, dependent: :destroy
  has_many :customers, dependent: :destroy
  has_many :resources, dependent: :destroy
  has_many :services, dependent: :destroy
  has_many :phone_numbers, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :schedule_templates, dependent: :destroy
  has_many :service_notifications, dependent: :destroy
  has_one :default_resource, -> { where is_default: true}, class_name: 'Resource', dependent: :destroy
  has_one :default_service, -> { where is_default: true}, class_name: 'Service', dependent: :destroy
  has_many :organizations, dependent: :destroy
  has_many :application_calendars, dependent: :destroy
  has_one :calendar_setting, dependent: :destroy
  has_many :notifications, dependent: :destroy

  # TODO: We can rename to User
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  # devise :database_authenticatable, :registerable,
  #        :recoverable, :rememberable, :trackable, :validatable
  store_accessor :ivr_text, :welcome, :closed_time_message, :menu1, :menu2, :menu3, :ask_phone, :appointment_success,
                 :appointment_error, :sms_text, :transferring_call, :incorrect_option

  # validates_presence_of :email, :phone, :schedule_id, :checksum

  #validates :phone, uniqueness: true, phone: {country_specifier: -> client { client.phone_country.try(:upcase) }}

  validates_uniqueness_of :sip, if: :sip?

  validates_inclusion_of :voice, in: TelephonyEngine.voices.map { |tmv| tmv[:voice] }, if: :voice?

  after_initialize :set_default_values
  validates_presence_of :first_name, :last_name, :phone

  after_create :create_user
  after_create :assign_default_role
  after_create :create_organization
  after_create :create_default_ivr
  after_create :set_default_resource_and_service
  after_create :create_contact

  enum role: [:admin]

  # has_one :agenda_app, through: :ivrs

  has_many :tropo_webhooks, through: :ivrs
  has_many :appointments, dependent: :destroy
  # accepts_nested_attributes_for :agenda_app

  has_attached_file :avatar

  Role::ROLES.keys.each do |key|
    define_method("is_#{key}?") do
      (self.roles.map(&:name).include? key.to_s)# rescue false 
    end
  end

  def set_default_values
    set_default_ivr_text
    set_default_appointment_params
  end

  def services_by(resource_id: nil)
    services = resource_id ? self.resources.find(resource_id)&.services : self.services
    services.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def resources_by(service_id: nil)
    resources = service_id ? self.services.find(service_id)&.resources : self.resources
    resources.map {|s| {'id' => s.id, 'name' => s.name}}
  end

  def set_default_ivr_text
    self.welcome ||= 'Hello, I am Laura the virtual assistant who can schedule appointments for you and transfer your calls'
    self.closed_time_message ||= 'Hello, I am Laura the virtual assistant. We are closed now.'    
    self.menu1 ||= 'Press 1 if you would like to make an appointment, press 2 in case of emergency'
    self.menu2 ||= 'The doctor told me to offer you the next possible appointment on %{time}. Press 1 to confirm this appointment. Press 2 to hear other availabilities'
    self.menu3 ||= 'You will now hear the next possible availabilities: Press 1 for %{time1}. Press 2 for %{time2}. Press 3 to hear other availabilities. Or press 9 to talk to the client.'
    self.ask_phone ||= 'To confirm your appointment, I need to enter your phone number in the system. Please enter your phone number followed by the hash key.'
    self.appointment_success ||= 'Thank you, your appointment for %{time} is confirmed.'
    self.appointment_error ||= 'Sorry, We could not create appointment.'
    self.sms_text ||= "Your appointment for %{time} is confirmed."
    self.transferring_call ||= 'Your call is now being transferred to agent.'
    self.incorrect_option ||= 'You entered an incorrect value.'
  end

  def set_default_appointment_params
    self.default_params ||= <<~EOS
      full_name=To complete
      email=to-complete@example.com
      address=To complete
      mobile=To complete
      phone=To complete
      country=BE
      description=To complete
      super_field=%{caller_id}
    EOS
  end

  before_save :set_phone_to_e164

  def set_phone_to_e164
    # self.phone = voxi_phone(self.phone, self.phone_country)
    self.phone = Phonelib.parse(self.phone).sanitized
  end

  # For adding support for more languages just return appropriate locale
  def locale
    TelephonyEngine.voices.find{|v| v[:voice] == self.voice}[:locale]
  end

  def default_params_hash
    h = {}
    default_params.split("\n").each do |line|
      key, value = line.split('=').map(&:strip)
      h[key.to_sym] = value
    end

    return h
  end

  # def create_agenda(attrs)
  #   self.update_attributes(attrs)
  #   SuperSaasSignUpJob.perform_now(self.id)
  #   self.agenda_sign_up_fields['success']
  # end

  def full_name
    "#{first_name} #{last_name}"
  end

  def create_default_ivr
    if ivrs.count.zero?
      ivr = Ivr.new(name: 'Default', client_id: self.id, organization_id: self.organizations[0].id)
      ivr.save
    else
      ivrs.each do |ivr|
        ivr.create(name: 'Default', organization_id: self.organizations[0].id)
      end
    end

  end

  def create_organization
    organization = organizations.create({ status: "active", name: self.company ? self.company : self.first_name + " " + self.last_name })

    addRelationTuple("/organization-" + organization.id.to_s, "owner", "client-" + self.id.to_s)
    addRelationTupleSet("/organization-" + organization.id.to_s, "manage", "/organization-" + organization.id.to_s, "owner")
    addRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/organization-" + organization.id.to_s, "owner")
    addRelationTupleSet("/organization-" + organization.id.to_s, "transfer-owner", "/app", "super-admin")

    addRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "owner")
    addRelationTupleSet("/app", "trial", "/organization-" + organization.id.to_s, "member")

    addRelationTupleSet("/app", "all", "/organization-" + organization.id.to_s, "owner")

    addRelationTupleSet("/organization-" + organization.id.to_s + "/billing", "manage", "/organization-" + organization.id.to_s, "owner")
  end

  # default_user
  def create_user
    users.create(default_user_params)
  end

  def default_user_params
    {name: "#{self.first_name} #{self.last_name}", email: self.email, number: self.phone, is_default: true}
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
      type: 'DummyAgenda',
      client_id: self.id,
      ivr_id: self.ivrs.first.id,
      ss_default_params: ss_default_params,
      default_resource_availability: BusinessHours::DEFAULT_AVAILABILITY
    )
    agenda.save
    agenda
  end

  def create_cronofy(server_region: nil, access_token: nil, refresh_token: nil)
    server_region = self.data_server if server_region.nil?
    if access_token.nil? && refresh_token.nil?
      cronofy = Cronofy::Client.new(
        client_id: ENV["CRONOFY_#{server_region}_CLIENT_ID"],
        client_secret: ENV["CRONOFY_#{server_region}_CLIENT_SECRET"],
        data_center: server_region.downcase
      )
    elsif access_token != nil && refresh_token.nil?
      cronofy = Cronofy::Client.new(
        access_token: access_token,
        data_center: server_region.downcase
      )
    else
      cronofy = Cronofy::Client.new(
        client_id:     ENV["CRONOFY_#{server_region}_CLIENT_ID"],
        client_secret: ENV["CRONOFY_#{server_region}_CLIENT_SECRET"],
        access_token: access_token,
        refresh_token: refresh_token,
        data_center: server_region.downcase
      )
    end

    puts "***************************************************check cronofy client*******************************************"
    puts cronofy.inspect

    if access_token && refresh_token
      userinfo = cronofy.userinfo
      puts userinfo.inspect
    end

    cronofy
  rescue => e
    puts "Create Cronofy Issue #{e}"
    if e.class == Cronofy::AuthenticationFailureError
      puts "regenerate access token of agenda"
      if access_token.nil? && refresh_token.nil?
        agenda = self.agenda_apps.first
      elsif access_token != nil && refresh_token.nil?
        agenda = self.agenda_apps.where(cronofy_access_token: access_token).first
      else
        agenda = self.agenda_apps.where(cronofy_access_token: access_token, cronofy_refresh_token: refresh_token).first
      end

      begin
        response = cronofy.refresh_access_token
        puts response.inspect
        puts "************************* refresh_access_token *********************************"

        if agenda
          agenda.update_columns(cronofy_access_token: response.access_token, cronofy_refresh_token: response.refresh_token)
        else
          agenda = self.application_calendars.where(access_token: access_token).first
          agenda.update_columns(access_token: response.access_token, refresh_token: response.refresh_token)
          Resource.where(application_access_token: access_token).each do |resource|
            resource.application_access_token = response.access_token
            resource.application_refresh_token = response.refresh_token
            resource.save
          end
        end

        create_cronofy(server_region: server_region, access_token: response.access_token, refresh_token: response.refresh_token)
      rescue => e
        puts e
        puts "************************* refresh_access_token error *********************************"

        if agenda
          default_resouorces = self.resources.where(calendar_type: "my_calendar", my_calendar_type: "default", client_id: self.id)

          calendar_id = ""
          unless agenda.calendar_id.nil? || agenda.calendar_id.blank?
            agenda_apps = self.agenda_apps.where("type = ? AND id != ?", "ClassicAgenda", agenda.id)
            if agenda_apps.count.positive?
              calendar_id = agenda_apps[0].conflict_calendars
              agenda_apps[0].update_attributes(calendar_id: calendar_id, calendar_account: agenda_apps[0].cronofy_profile_name)
              default_resouorces.update_all(calendar_id: calendar_id)
            end
          end

          conflict_calendars = ""
          unless agenda.conflict_calendars.nil? || default_resouorces.count.zero?
            conflict_calendars = default_resouorces[0].conflict_calendars
            if conflict_calendars.index(agenda.conflict_calendars) != nil
              if conflict_calendars.index(agenda.conflict_calendars).positive?
                conflict_calendars.slice! "," + agenda.conflict_calendars
              else
                conflict_calendars.slice! agenda.conflict_calendars + ","
              end

              default_resouorces.update_all(conflict_calendars: conflict_calendars)
            end
          end
          agenda.destroy

          member_resources = Resource.where(calendar_type: "team_calendar", team_calendar_client_id: self.id)
          member_resources.each do |resource|
            resource.update_columns(conflict_calendars: conflict_calendars, calendar_id: calendar_id)
          end

          return 'wrong_refresh_token'
        end
      end
    end
  end

  def create_contact
    customers.create( first_name: "Axel", last_name: "Voxi", email: "contact@voxi.ai", gender: 1, birthday: "1988-03-14".to_date,
                      street: "102 South Brook Lane", city: "New York", zipcode: "10003", phone_country: "us",
                      phone_number: "+14158586273", notes: "This is our demo client")
    contacts.create( phone: '+14158586273',country: 'us',customer_id: self.customers.first.id )
    self.customers.first.update(eid: self.customers.first.id)
  end
  # Bug: if client changes his email or email of that user, we won't be able to find default user
  def default_user
    # users.find_by(email: self.email) || users.build(default_user_params) # try to fix nil default_user
    users.find_by(is_default: true)
  end

  def assign_default_role
    self.add_role(Role::ROLES[:client]) if self.roles.blank?
  end

  def short_name
    full_name.split(" ").map{|c| c.capitalize[0] }.join() rescue "JD"
  end

  def full_address
    [address_one, address_two,city,state,country].join(' ')
  end

  def gtm?
    trigger = false
    trigger = true if self.gtm_triggered.present? and self.gtm_triggered == true
    trigger
  end

  def data_server
    (self.server_region.nil? || self.server_region.blank?) ? 'DE' : self.server_region
  end

  private

  def set_default_resource_and_service
    user_name = self.first_name + ' ' + self.last_name
    resource = Resource.new(ivr_id: self.ivrs.first.id, client_id: self.id, enabled: true, is_default: true, name: user_name, ename: user_name)
    resource.save

    service_30 = Service.new(name: I18n.t('services.demo.label2'), ename: I18n.t('services.demo.label2'), order_id: 1, duration: 30, is_default: true, enabled: true, client_id: self.id, ivr_id: self.ivrs.first.id)
    service_30.resource_ids = [resource.id]
    service_30.save

    services = Service.where(ivr_id: self.ivrs.first.id, client_id: self.id)
    services.update_all(preference: {"pre_confirmation"=>"false", "enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"false", "sms_enabled"=>"false", "ai_phone_assistant_enabled"=>"false"})
    # resources = Resource.where(ivr_id: self.ivrs.first.id, client_id: self.id)
    # resources.update_all(preference: {'enabled'=>'true', 'widget_enabled'=>'true', 'phone_assistant_enabled'=>'true', 'chat_enabled'=>'true', 'sms_enabled'=>'true', 'ai_phone_assistant_enabled'=>'false'})

    service_30_dup = Service.new(name: I18n.t('services.demo.label2'), ename: I18n.t('services.demo.label2'), duration: 30, is_default: false, enabled: true, client_id: self.id, ivr_id: self.ivrs.first.id, eid: service_30.id)
    service_30_dup.agenda_type = "ClassicAgenda"
    service_30_dup.order_id = (service_30.order_id || 0) + 1
    service_30_dup.save
    Service.where(id: service_30_dup.id).update_all(client_id: nil)

    resource_dup = Resource.new(ivr_id: self.ivrs.first.id, client_id: self.id, enabled: true, is_default: false, name: user_name, ename: user_name, eid: resource.id)
    resource_dup.save
    Resource.where(id: resource_dup.id).update_all(client_id: nil, agenda_type: "ClassicAgenda")

    service_30_dup.resource_ids = [resource_dup.id]
    service_30_dup.save
  end

end
