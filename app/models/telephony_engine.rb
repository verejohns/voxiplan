class TelephonyEngine
  attr_reader :node

  def initialize(node, options={})
    @node = node
    @options = options
    # puts "******* @options #{@options.to_yaml}"
  end

  def self.create(name, node, options={})
    case name
      when 'tropo'
        TropoEngine.new(node, options)
      when 'twilio'
        TwilioEngine.new(node, options)
      when 'voxi_sms'
        VoxiSMSEngin.new(node, options)
      else
        raise 'No'
    end
  end

  def next_node_path(node, query_params = {})
    node_id = node.is_a?(Node) ? node.id : node
    url = "/run/#{node_id}"
    url += '?' + query_params.map{|k,v| "#{k}=#{v}"}.join('&') if query_params.present?
    url
  end

  def self.voices
    @voices ||= YAML.load(File.read(File.expand_path('db/twilio_voices.yml'))).symbolize_keys[:voices]
  end
end