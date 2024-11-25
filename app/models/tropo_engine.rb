class TropoEngine < TelephonyEngine
  def say(text = nil)
    set_next_node
    tropo.say to_ssml(text || node.text) # voice handled in default_options see #tropo
    tropo.response
  end

  def menu
    set_next_node(node, parse_response: true)
    value = node.choices.keys.map{|k| k[-1]}.join(', ')
    tropo.ask(ask_params.merge(choices(value)))
    tropo.response
  end

  def gather_number
    set_next_node(node, parse_response: true)
    tropo.ask(ask_params.merge(choices(gather_number_choice_value)))
    tropo.response
  end

  def transfer(to, from, text = '')
    # todo. Handle timeout
    opts = {to: to}
    # Tropo does not transfer if from is invalid
    opts[:from] = from if Phonelib.valid?(from)
    tropo.say(value: to_ssml(text))
    tropo.transfer(opts)
    tropo.response
  end

  def record(text, url)
    set_next_node(node, parse_response: true)
    puts "********** going to record at URL = #{url}"
    tropo.say(value: to_ssml(text))
    tropo.record(
        # url:  "https://#{ENV['DOMAIN']}/webhooks/recording",
        url: url,
        username: ENV['AWS_ACCESS_KEY_ID'],
        password: ENV['AWS_SECRET_ACCESS_KEY'],
        method: 's3',
        name: node.name,
        choices: {
            terminator: "#"
        })
    tropo.response
  end

  # available options
  # to:
  # appointment_time:
  # call_id
  # client_id
  def send_sms(options = {})
    url = 'https://api.tropo.com/1.0/sessions'
    query = {
      token: ENV['TROPO_MESSAGING_API_KEY'],
      appointment_time: options[:appointment_time].to_i,
    }.merge(options.slice(:to, :client_id, :call_id))
    HTTParty.post(url, query: query)
  end

  def get_response
    return node.test_input if node.test_input
    return OpenStruct.new unless tropo_response
    tropo_response[:result][:actions][node.name.to_sym]
  end

  def set_next_node(node = @node.next_node, params={})
    tropo.redirect(next_node_path(node, params))
  end

  def ask_params
    {
        name: node.name,
        say: say_objects,
        timeout: node.timeout,
        attempts: node.tries || 2,
        required: node.required.nil? ? true : node.required,
        bargein: node.interruptible.nil? ? true : node.interruptible,
    }
  end

  def choices(value)
    {
        choices: {
            value: value,
            mode: 'dtmf'
        }
    }
  end

  def gather_number_choice_value
    if node.input_min_length && node.input_max_length
      "[#{node.input_min_length}-#{node.input_max_length} DIGITS]"
    else
      "#{node.input_min_length || node.input_max_length} DIGIts"
    end
  end

  def say_objects
    say = []
    say << { value: to_ssml(node.try1_invalid_node.text), event: 'nomatch'} if node.try1_invalid_node.present?
    say << { value: to_ssml(node.try1_timeout_node.text), event: 'timeout'} if node.try1_timeout_node.present?
    say << { value: to_ssml(node.text) }
    say
  end

  def tropo
    return @tropo if @tropo
    default_options = {
      voice: node.voice || node.ivr.voice,
    }

    @tropo ||= Tropo::Generator.new(default_options)
    @tropo.on :event => 'hangup', :next => next_node_path(node.hangup_next)
    @tropo
  end

  def tropo_response
    @options[:tropo_session]
  end

  private

  def to_ssml(text)
    "<speak>#{SSMD.to_ssml(text)}</speak>"
  end
end