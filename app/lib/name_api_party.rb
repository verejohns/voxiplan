class NameApiParty
  include HTTParty
  debug_output $stdout
  format :json

  base_uri 'http://api.nameapi.org/rest/v5.3'

  def initialize(api_key)
    @api_key = api_key
  end

  def self.test
    HTTParty.post('http://api.nameapi.org/rest/v5.3/parser/personnameparser?apiKey=e15709c43d00c74f0028e8bf05ea8ba7-user1', headers: {'Content-Type' => 'application/json'}, body: parse_name_requset_body('John Brown'))
  end

  def parse_name(full_name)
    url = "/parser/personnameparser"

    if full_name.present?
      begin
        options = { headers: headers, query: { apiKey: @api_key}, body: parse_name_request_body(full_name)}
        response = self.class.post(url, options).parsed_response
        person = response['matches'][0]['parsedPerson']
        terms = person['outputPersonName']['terms']
        gender = person['gender']['gender'][0].downcase
        first_name = terms.find{|t| t['termType'] == 'GIVENNAME'}.try(:[], 'string')
        last_name = terms.find{|t| t['termType'] == 'SURNAME'}.try(:[], 'string')
      rescue StandardError => e
        puts "********* Error while fetching name #{e.message}"
        puts "********* #{e.backtrace}"
      end
    else
      gender = ''
      first_name = 'X.'
      last_name = 'X.'
    end

    {first_name: first_name, last_name: last_name, gender: gender}
  end

  private

  def headers
    {'Content-Type' => 'application/json'}
  end

  def parse_name_request_body(full_name)
    {
        "context"=>{"priority"=>"REALTIME", "properties"=>[]},
        "inputPerson"=>{
         "type"=>"NaturalInputPerson",
         "personName"=>{
             "nameFields"=>[{"string"=>full_name, "fieldType"=>"FULLNAME"}]
         },
         "gender"=>"UNKNOWN"}
    }.to_json
  end

end