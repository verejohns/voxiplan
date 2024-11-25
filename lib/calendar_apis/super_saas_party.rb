class SuperSaasParty
  include HTTParty
  debug_output $stdout

  base_uri 'www.supersaas.com/api'

  def initialize(schedule_id, checksum)
    @schedule_id = schedule_id
    @checksum = checksum
  end

  def free_slots(from)
    url = "/free/#{@schedule_id}.json"
    options = { query: { from: from.to_s(:db), checksum: @checksum }}
    response = self.class.get(url, options)['slots']

    # convert dates to Ruby objects
    response.map do |r|
      %w[start finish].each{|date| r[date] = DateTime.parse(r[date])}
    end

    response
  end

  def create_appointment(params = {})
    url = "/bookings.json"
    booking_params = params.dup
    booking_params[:start] = params[:start].to_s(:db)
    booking_params[:finish] = params[:finish].to_s(:db)
    options = { query: { checksum: @checksum,
                         schedule_id: @schedule_id,
                         booking: booking_params,
                         webhook: true}}

    self.class.post(url, options)
  end

end