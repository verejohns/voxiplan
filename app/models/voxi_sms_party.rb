class VoxiSMSParty
  include HTTParty
  debug_output $stdout

  base_uri 'https://voxisms.voxiness.com'

  def initialize(customer_id, secret, id = nil)
    @customer_id = customer_id
    @secret = secret
    @id = id || SecureRandom.uuid
  end


  # VoxiSMSParty.test(msg: 'e4', id: TextMessage.last.uuid)
  def self.test(msg:, rec: nil, id:)
    VoxiSMSParty.new(ENV['VOXI_SMS_CUSTOMER_ID'], ENV['VOXI_SMS_SECRET'], id)
        .send_msg(recipient: rec || ENV['VOXI_SMS_RECIPIENT'], message: msg)
  end

  # @param
  # recipient: +32484605312
  # message: "Test 1004"
  # def send_msg_old(params = {})
  #   url = "/publisher/#{@customer_id}"
  #   params[:id] = SecureRandom.uuid
  #   params[:webhookUrl] ||= 'https://hook.integromat.com/5bfl2rsui5of4nnyc48e0rrs1gav7gud'
  #   call(:post, url, params)
  # end

  # @param
  # recipient: +32484605312
  # message: "Test 1004"
  def send_msg(params = {})
    url = "/message-queue"
    params[:id] = @id
    params[:secretKey] = @secret
    params[:customerId] = @customer_id
    params[:webhookUrl] ||= "#{ENV['DOMAIN']}/webhooks/voxi_sms"
    call(:post, url, params)
  end

  private

  # method: Symbol, http_method i-e :get
  # path: String, url path i-e '/customers/'
  # options: Hash, i-e {query: {key: value}, body: {key: value}}
  #  -> see HTTParty for all available options
  def call(method, path, params = {})

    params_type =  method == :get ? :query : :body
    options = {}
    options[params_type] = params.to_json
    options[:headers] =
        {
            'X-Api-Key' => ENV['VOXI_SMS_API_KEY'],
            'Content-Type' => 'application/json',
        }

    response = self.class.send(method, path, options)
    parse_response(response)
  end

  def parse_response(response)
    response.parsed_response.merge(code: response.code)
  end

end