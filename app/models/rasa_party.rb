class RasaParty
  include HTTParty
  debug_output $stdout

  base_uri ENV["RASA_REST_URL"]

  # Use only if different Rasa server for each language
  # def initialize(session_id, locale = I18n.locale)
  def initialize(session_id, assistant_name, language, timezone, locale, platform)
    @session_id = session_id
    @assistant_name = assistant_name
    @language = language
    @timezone = timezone
    @locale = locale
    @platform = platform
    # self.class.base_uri locale.to_s.start_with?('fr') ? ENV["RASA_REST_URL_FR"] : ENV["RASA_REST_URL"]
  end

  def self.test(msg)
    RasaParty.new('0f4e2143d985765dddd271d007995dfa', 'Laura', 'en', 'Europe/Brussels', 'en-US-US', 'api').chat(message: msg)
  end

  # @param
  # message: "Hello"
  def chat(params = {})
    url = "/webhooks/rest/webhook"
    params[:sender] = @session_id
    params[:assistant_name] = @assistant_name
    params[:language ] = @language
    params[:timezone] = @timezone
    params[:locale] = @locale
    params[:platform] = @platform
    puts ">>>> User: #{params}"
    call(:post, url, params)
  end

  private

  # method: Symbol, http_method i-e :get
  # path: String, url path i-e '/customers/'
  # options: Hash, i-e {query: {key: value}, body: {key: value}}
  #  -> see HTTParty for all available options
  def call(method, path, params = {})

    params_type =  method == :get ? :query : :body
    options = {timeout: 120}
    options[params_type] = params.to_json
    options[:headers] =
        {
            # 'X-Api-Key' => @api_key,
            'Content-Type' => 'application/json',
        }

    response = self.class.send(method, path, options)
    parse_response(response)
  end

  def parse_response(response)
    res = response.parsed_response
    puts ">>>> BOT: #{res.inspect}"
    # custom = res.find{|r| r['custom'].present?}
    # return custom['custom'] if custom.present?
    res.respond_to?(:[]) ? res.map{|r| r['text']}.join(' ') : res.text
  end

end