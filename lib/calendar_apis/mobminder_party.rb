require 'httparty'

class MobminderParty
  include HTTParty
  include Skylight::Helpers
  debug_output $stdout

  base_uri 'https://api.mobminder.com'

  attr_accessor :configs
  def initialize(login, password, key)
    @login = login
    @password = password
    @key = key
    self.class.default_params lgn: @login, pwd: @password, kid: @key
    set_configs
  end

  def set_configs
    # no need to fetch configs multiple times in single request
    return if @configs #&& @configs.any?
    url = '/query/config.php'
    response = self.class.get(url)
    @configs = parse_response(response)
  end

  def key_value_map(keys, values)
    values.map{|value| HashWithIndifferentAccess[keys.each_with_index.map {|k,i| [k, value[i]]}]}
  end

  def services
    keys =  %w[id name note duration staffing cssColor cssPattern ereservable]
    values = @configs['#C_dS_workcode']
    key_value_map(keys,values)
  end

  def resources
    keys =  %w[id resourceType name signature note]
    values = @configs['#C_dS_resource']
    key_value_map(keys,values)
  end

  # mandatory posts
  # - id: the visitor unique id
  # optional posts
  # - history: includes visitor history. Range [0,1]. Default:0 (history not included)
  instrument_method
  def appointments(options = {})
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-visitor id data-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    puts options.inspect
    raise 'visitor id required to get Mobminder appointments' if options[:id].nil? || options[:id].empty?
    allowed_opts = %i[id history]
    opts = options.slice(*allowed_opts).compact
    url = '/query/visiapps.php'
    response = self.class.get(url, query: opts)
    values = parse_response(response)['#C_dS_reservation']
    return [] unless  values

    keys  = %w[id created creator creatorId changed changer changerId deleted deletorId cueIn cueOut iscluster waitingList cssColor cssPattern cssTags rescheduled serieId snext sprev archived note bookingcode prebooking]
    appointments = key_value_map(keys, values)

    resource_values = parse_response(response)['#C_dS_attendee']
    resource_keys = %w[groupId resourceType resourceId]
    resources = key_value_map(resource_keys, resource_values)

    service_values = parse_response(response)['#C_dS_performance']
    service_keys = %w[groupId workCodeId]
    services = key_value_map(service_keys, service_values)

    appointments.each do |appointment|
      appointment[:resources] = resources.select{|r| r[:groupId] == appointment[:id]}
      appointment[:services] = services.select{|s| s[:groupId] == appointment[:id]}
    end

    appointments
  end

  def service(service_id)
    services.find{|service| service['id'] == service_id}
  end

  def resource(resource_id)
    resources.find{|resource| resource['id'] == resource_id}
  end

  def workexperts
    keys = %w[groupId resourceId]
    values = @configs['#C_dS_workexpert']
    key_value_map(keys, values)
  end

  # allowed options
  # * mode1:  search using a workcode
  # workcode(required): a valid workcode unique id
  # =================
  # * mode2: search using resources, duration, staffsize and duration
  # bCals(required): a valid resource unique id, or a string of valid ids like "6312!6995!6733!6311!8758"
  # uCals(optional): a valid resource unique id
  # fCals(optional): a valid resource unique id
  # staffsize(optional): a numeric [1 to count(uCals)], defaults to 1
  # duration(optional): a number of time slices (see time granularity in the account settings), defaults to 1
  # tboxing(optional): a valid time boxing unique id or a string of valid ids like "14580!15870!10999", defaults will search considering the resources hourlies
  # =================
  # ** optional for both modes
  # from: date for the start of this query in time stamp format [2018-05-18] or zero. Defaults to the current time. Zero starts from current time.
  # limit: Tunes the number of returned availabilities. Range [1 to 300]. Defaults is automatic and depends on the number of resources implied.
  # aggregate: Availabilities returned are subsequent or ahead existing reservations.
  instrument_method
  def free_slots(options = {})
    return @slots if @slots #&& @slots.any?
    url = '/query/availabilities.php'
    allowed_opts = %i[workcode bCals uCals fCals staffsize duration tboxing from limit aggregate]
    opts = options.slice(*allowed_opts).compact
    opts[:from] = opts[:from].to_s.split(' ').first
    # params = { query: { bCals: business_cal}.merge(opts)}
    params = { query: opts }

    begin
      response = self.class.get(url, params)

      @slots = parse_response(response)['#C_dS_reservation'].map do |s|
        {start: Time.zone.parse(s[1]), finish: Time.zone.parse(s[2])}
      end
    rescue => e
      puts e
      raise NoAvalibilityError
    end
    @slots
  end

  def tboxing(workcode)
    worktboxing = @configs['#C_dS_worktboxing']
    return {} if worktboxing.blank? || workcode.blank?
    tboxing = worktboxing.select{|wb| wb[0] == workcode}.map{|a| a[1]}.join('!').presence
    {tboxing: tboxing}.compact
  end
  # Birthday variants: (accepted separators are space, dot, slash and minus [/.-], accepted formats are YYYY MM DD or DD MM YYYY)
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & birthday = 1970.12.30
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & birthday = 1970% 2012% 2030
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & birthday = 1970-12-30
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & birthday = 1970-12-5
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & birthday = 5-12-1970
  #  //
  # Mobile variants: (6 digits give to 1 / 1.000.000 precision)
  #  //
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & mobile = + 32493655599
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & mobile = 0493655599
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & mobile = 3655599
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & mobile = 599
  #  //
  # Birthday and mobile combination:
  #  //
  # http: //localhost/api/query/visitors.php? lgn = vx & pwd = vx & kid = 18738 & web = 1 & mobile = 599 & birthday = 30.12.1970
  # available options: mobile, birthday
  def visitors(options = {})
    url = '/query/visitors.php'
    response = self.class.get(url, query: options)
    values = parse_response(response)['#C_dS_visitor']
    values ? key_value_map(visitor_keys, values) : []
  end


  # required params
  # -> cueIn: date and time for the start of this time reservation [2019-12-30 14:15] (*1)
  # -> cueOut: date and time for the start of this time reservation [2019-12-30 14:45] (*1)
  # -> bCals: id's of valid objects of this resource class, separated by ! (exclam mark) (*2)
  # optional posts
  # -> uCals: id's of valid objects of this resource class, separated by ! (exclam mark)
  # -> fCals: id's of valid objects of this resource class, separated by ! (exclam mark)
  # -> visitors: id's of valid visitor objects, separated by ! (exclam mark)
  # -> workcodes: id's of valid workcode objects, separated by ! (exclam mark) (*3)
  # -> note: alpha num text
  # -> cssColor: id of a valid object of this class
  # -> cssPattern: id of a valid object of this class
  def create_appointment(params)
    allowed_options = %i{id cueIn cueOut bCals uCals fCals visitors workcodes note cssColor cssPattern}
    url = '/post/reservation.php'
    params[:id] = 0 if params[:id].nil? || params[:id] == ""
    %i[cueIn cueOut].each{|p| params[p] = params[p].strftime("%F %H:%M") }
    query = params.slice(*allowed_options).compact
    response = self.class.get(url, query: query)
    parse_response(response)['#C_dS_reservation'] rescue false
  end

  #
  # mandatory posts
  #  - id: positive, must match an existing reservation.
  #
  # optional posts
  #  - note: alpha num text. The appointment note can be changed at deletion time.
  def delete_appointment(params)
    allowed_options = %i{id note}
    url = '/delete/reservation.php'
    query = params.slice(*allowed_options).compact
    response = self.class.get(url, query: query)
    # values = parse_response(response)['#C_dS_visitor'] rescue false
    values = parse_response(response)['#C_dS_reservation'] rescue false
    keys  = %w[id created creator creatorId changed changer changerId deleted deletorId cueIn cueOut iscluster waitingList cssColor cssPattern cssTags rescheduled serieId snext sprev archived note bookingcode prebooking]
    key_value_map(keys,values)
  end

  # ## new visitor
  # ### mandatory posts
  #   - id: zero or negative, this forces the creation of a new visitor.
  #   - lastname: zero or negative, this forces the creation of a new visitor.
  #   - firstname: zero or negative, this forces the creation of a new visitor.
  #
  # ### optional posts
  #   - mobile: international formatted mobile number with heading country code and heading +. Example: +33659123456 (*1) or locally expressed mobile number with heading trunk 0. Example: 0493655599 (*2)
  #   - phone: local or international formatted phone number.
  #   - birthday: straight sorting brithday format like 19991231. (*3)
  #   - email: properly formatted email value, including @ and a min 2 digits tail.
  #   - language: numeric field ranging [0 to 7]. See object description for more details on the right value. Defaults to the account set default language.
  #   - gender: 0 for female, 1 for male.
  #   - company: alpha num free text.
  #   - address: alpha num free text.
  #   - residence: alpha num free text.
  #   - zipCode: alpha num free text.
  #   - city: alpha num free text.
  #   - country: alpha num free text.
  #   - registration: alpha num free text.
  #   - reference: alpha num free text.
  #   - note: alpha num free text (*4).
  #   - cssColor: id of a valid css color object as provided by the call on the config interface (only class 3 and type 80).
  #   - cssPattern: id of a valid css color object as provided by the call on the config interface (only class 3 and type 81).
  #   - cssTags: ids of a valid css tag objects as provided by the call on the config interface, separated by exclam mark (only class 3 and type 82).
  #
  # caution
  # (1*) mobiles are screened for correct number of digits (this is depending the country code). when a wrongly formatted reaches the api, it is discarded.
  # (2*) All mobile numbers are turned to international format. When the heading trunk 0 is detected, it is converted into the account regional country code found in the Mobminder setup.
  # (3*) Birthday may not be a future date. Year, month and day range are screened.
  # (4*) Note that any free text field is screened for SQL injection and script injection.
  #
  # ## existing visitor
  # ### mandatory posts
  #   - id: positive, must match an existing visitor.
  # ### optional posts
  #   - are identical to the new visitor section optional posts.

  def create_visitor(params)
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=logs for mobile conversion-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    puts params.inspect
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=logs for mobile conversion-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    allowed_options = %i{id lastname firstname mobile phone birthday email language gender company address residence zipCode city country registration reference note cssColor cssPattern cssTags}
    url = '/post/visitor.php'
    params[:id] ||= -1 # create , report 0 not working
    %i[birthday].each{|p| params[p] = params[p].strftime("%Y%m%d") if params[p] }
    query = params.slice(*allowed_options).compact
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=logs for mobile conversion-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    puts allowed_options.inspect
    puts query.inspect
    puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=logs for mobile conversion-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
    response = self.class.get(url, query: query)

    values = parse_response(response)['#C_dS_visitor']
    keys  = %w[id created creator creatorId changed changer changerId deleted deletorId gender firstname lastname company address residence zipCode city country email mobile phone language birthday registration cssColor cssPattern cssTags note]
    key_value_map(keys, values).first
  end

  private

  def visitor_keys
    %w[id gender lastname firstname birthday mobile phone address zipCode city email]
  end


  # This method converts HTML response to hash

  # INPUT
  # response = """
  #     <data>
  #     #C_dS_resource
  #     6978|2|Olivier||Je suis la seule resource dans cet agenda :)
  #     #C_dS_workexpert
  #     13805|6978
  #     13807|6978
  #     13808|6978
  #     #C_dS_workcode
  #     13805|Maquillage permanent||4
  #     13807|Retouche maquillage||2
  #     13808|Extension de cils glamour|oh mon dieux comme tu vas être belle!|3
  #     </data>
  # """

  # OUTPUT
  # {"#C_dS_resource"=>  [["6978", "2", "Olivier", "", "Je suis la seule resource dans cet agenda :)"]],
  #  "#C_dS_workexpert"=>[["13805", "6978"], ["13807", "6978"], ["13808", "6978"]],
  #  "#C_dS_workcode"=>
  #      [["13805", "Maquillage permanent", "", "4"],
  #       ["13807", "Retouche maquillage", "", "2"],
  #       ["13808", "Extension de cils glamour", "oh mon dieux comme tu vas être belle!", "3"]]}
  instrument_method
  def parse_response(response)
    puts "******* response #{response}"
    data  = response.force_encoding("iso-8859-1").match(/<data>(.+?)<\/data>/m)[1]
    rows = data.strip.split(/(#C_dS_\S*)/).reject{|e|e.empty?}
    hash = {}
    key = nil
    rows.each do |r|
      if r =~ /^#C_dS/
        key = r
      else
        hash[key] = r.split("\r").reject(&:empty?).map{|a| a.split('|').map{|v| v.strip}}
        #row = r.split("\n").reject(&:empty?)
        #hash[key] = row.map{|a| a.split('|').map{|v| v.strip}}
      end
    end
    hash
  end

end
