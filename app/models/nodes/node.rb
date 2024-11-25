class Node < ApplicationRecord
  include InterpolationUtils
  include PhoneNumberUtils
  include JSONConvertEntity

  belongs_to :ivr
  # used for send_email, send_sms and transfer
  has_and_belongs_to_many :users
  delegate :default_user, to: :ivr

  has_paper_trail

  def self.model_name
    return super if self == Node
    Node.model_name
  end

  def update_users(users)
    old_ids = self.users.pluck(:id)
    new_ids = users.pluck(:id)
    remove_ids =  old_ids - new_ids
    add_ids = new_ids - old_ids
    self.users.delete(self.users.where(id: remove_ids))
    self.users << User.where(id: add_ids)
  end

  # add user if does not exist already
  def add_user(user)
    update_users(self.users + [user]) unless self.users.find_by(id: user.id)
  end

  def remove_user(user)
    update_users(self.users - [user]) if self.users.find_by(id: user.id)
  end

  def current_call
    Call.find(data[:current_call_id]) if data[:current_call_id]
  end

  validates :name, presence: true, uniqueness: {scope: :ivr_id}

  def current_customer
    Customer.find_by(id: data[:current_customer_id]) || Customer.new
  end

  def next_node
    get_node(self.next)
  end

  def get_node(name)
    ivr.nodes.find_by name: name
  end

  def invalid_next_node
    get_node(self.invalid_next)
  end

  def timeout_next_node
    get_node(self.timeout_next)
  end

  def try1_invalid_node
    get_node(self.try1_invalid)
  end

  def try1_timeout_node
    get_node(self.try1_timeout)
  end
  def internal_error_next
    get_node('internal_error')
  end

  def client_country
    self.ivr.client.country_code
  end

  def disabled_next_node
    get_node(self.next_nodes['disabled']) rescue nil
  end

  def hangup_next
    # next_nodes: {disabled: next_node}
    next_given = self.next_nodes.try(:[], 'hangup')
    return get_node(next_given) if next_given
    current_call.missed_call! if self.notify_hangup?
    self.notify_hangup? ? get_node('hangup_mail') : get_node('hang')
  end

  def run(options={})
    puts "****** Running node ##{self.id} #{self.type} (#{self.name})"
    puts "****** node options #{options}"
    @options = options
    if kind_of?(TelephonyNode) && telephony.class == TwilioEngine && telephony.get_response[:call_status] == 'completed'
      return hangup_next.run(options) unless %w[hangup_mail hang].include?(self.name)
    end
    return next_node.run(options) if !self.enabled && next_node.present?
    return disabled_next_node.run(options) if !self.enabled && disabled_next_node.present?
    execute
  rescue Exception => e
    NoMethodError
    puts "*************** Internal Error: #{e.message}"
    return next_node.run(options) unless exit_on_error?
    puts e.backtrace.to_yaml
    ClientNotifierMailer.generic_email(to: ENV['ERROR_MAIL_RECIPIENTS'],
                                       subject: "[Voxiplan Error] #{e.message}",
                                       body: e.backtrace.join("\n")).deliver_later
    logger.info "*************** Internal Error: #{e.message}"
    unless internal_error_next.nil?
      internal_error_next.run if internal_error_next.id != self.id # prvent infinite loop
    end
  end

  def data
    # TODO: Fetch time at runtime
    data = @options[:session_data]
    data ||= {}
    data['current_time'] = Time.current
    # I think we don't need to convert strings to dates now, ActiveRecord store does handle this
    # convert_dates(data)

    # puts "* da #{data.inspect}"
    data.symbolize_keys!
  end

  def test_input
    return unless @options[:test_input]
    test_input = @options[:test_input]
    OpenStruct.new({value: test_input, speech_result: test_input, url: test_input, upload_status: 'success', disposition: test_input})
  end

  def save_data(value, key: nil)
    key ||= self.name
    puts "going to save save data #{key}  = #{value}"
    data[key.to_sym] = value
    # current_call.save_data(key.to_sym, value)
  end

  def formatted_time(time, locale: nil, format: nil)
    locale ||= locale_from_voice
    format ||= interpolated_value(self.parameters['time_format']).try(:to_sym) rescue :custom
    format ||= :custom

    if time.is_a?(Time) || time.is_a?(DateTime)
      format = :long unless I18n.exists?("time.formats.#{format}", locale)
    elsif time.is_a?(Date)
      format = :long unless I18n.exists?("date.formats.#{format}", locale)
    end

    I18n.l(time, format: format, locale: locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end

  def interpolated_text
    # Convert time strings
    @interpolated_text ||= self.text % dup_data rescue self.text
  end

  # format dates and store in a duplicate object
  # Prevent changes to original data object using duplicate data object.
  def dup_data
    return @dup_data if @dup_data.present?
    @dup_data ||= data.dup
    @dup_data.each do |key,val|
      # if val.respond_to?(:day) && val.respond_to?(:month) # seems like a date
      if val.kind_of?(Date) || val.kind_of?(Time) || val.kind_of?(DateTime)
        @dup_data[key] = formatted_time(val)
      end
    end

    @dup_data
  end

  # TODO: Very important, we should not store our data in session because in session dates are converted to strings
  # here we are converting time_strings again to time ojbects. This may cause unexpected behaviors
  # Better solution: We now have `Call` model, we should store all data in db for every call
  # Another Workaround: Keep track of date fields then only convert these. say if slot1_date is a data field then in session we
  # should store this key, Then only convert these keys instead of trying to convert all the dates

  # convert all string dates to ruby object
  # storing dates to session converts to string. with this method we can convert back to dates
  def convert_dates(hash)
    hash.each do |key,val|

      ret  = begin
        raise 'Do not convert' if no_conversion key.to_sym
        Time.parse(val)
      rescue
        val
      end

      hash[key] = ret
    end
  end

  def no_conversion(key)
    %i[tropo_call_id search_by_time
     group1_day group1_start group1_finish
     group2_day group2_start group2_finish
     service_id resource_id choosen_resource choosen_service bCals
    ].include?(key) || key.match(/^(resource|service)_id\d$/)
  end

  def start_node?
    # self.id == client.start_node_id
    self.name == 'say1'
  end


  # TODO: Make sure all locale are valid for rails to prevent something like `Error: "ca-ES" is not a valid locale`
  def locale_from_voice(voice = nil)
    self.ivr.voice_locale[0..1] || 'en-US'
  end

  def locale_from_message(voice = nil)
    self.ivr.message_locale[0..1] || 'en-US'
  end

  def timeout?
    puts "*********** in timoute #{telephony.get_response.disposition == 'TIMEOUT'}"
    puts telephony.get_response.to_yaml
    telephony.get_response.disposition == 'TIMEOUT'
  end

  def execute
    raise "I don't know what to run. Please implement execute in child classes."
  end

  # def handle_response
  #   puts "******* Handle response #{@options.inspect}"
  #
  #   get_node(next_node_name).run
  # end

=begin
  # Running node #2017 AgendaApi (agenda_services)


=end

  def telephony
    TelephonyEngine.create(telephony_name, self, @options)
  end

  def telephony_name
    self.ivr.preference['voice_engin'] || 'twilio'
  end

  def agenda_app
    dummy_agenda = DummyAgenda::new
    dummy_agenda.ivr_id = self.ivr.client.ivrs.first.id
    dummy_agenda.client_id = self.ivr.client.id
    self.ivr.client.agenda_apps.count.zero? ? dummy_agenda : self.ivr.client.agenda_apps.first
  end

  # if true would say internal error on exception. if false will try next node
  def exit_on_error?
    true
  end
end
