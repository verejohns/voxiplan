class TropoWebhook < ApplicationRecord
  belongs_to :client, optional: true # TODO: Remove direct association.
  belongs_to :call, optional: true, foreign_key: :internal_call_id

  scope :in, -> {where(direction: 'in')}
  scope :out, -> {where(direction: 'out')}
  scope :cdr, -> {where(event: 'cdrCreated')}
  scope :calls, -> {cdr.where(resource: 'call')}
  scope :sms, -> {cdr.where(resource: 'sms')}
  scope :sms_count, -> {sms.sum(:message_count)}
  scope :appointments_count, -> {joins(:call).merge(Call.has_appointments).count}
  scope :duration_in_minutes, -> {sum(:duration_minutes)}

  def self.summary
    @report = {}
    @report[:total_confirmed_appointments] = appointments_count #|| @client.appointments.between(start_date, end_date).count
    @report[:total_incoming_calls] = calls.in.count
    @report[:total_incoming_calls_minutes] = calls.in.duration_in_minutes
    @report[:total_outgoing_calls] = calls.out.count
    @report[:total_outgoing_calls_minutes] = calls.out.duration_in_minutes
    @report[:total_sms] = sms_count
    @report
  end

  # "webhook"=>
  #     {"data"=>
  #          {"callId"=>"1c8930d2164dbfda0064b15e039d9317",
  #           "reason"=>"JOINED",
  #           "applicationType"=>"tropo-web",
  #           "messageCount"=>0,
  #           "parentCallId"=>"none",
  #           "parentSessionId"=>"4c05df3415753de9f560e04ac412e790",
  #           "sessionId"=>"7e4c73da057f88ac7193c520637ae4b1",
  #           "network"=>"SIP",
  #           "initiationTime"=>"2017-11-14T11:43:55.145+0000",
  #           "duration"=>21116,
  #           "accountId"=>"83346",
  #           "startUrl"=>"https://vtwo.herokuapp.com/welcome.json",
  #           "from"=>"Anonymous",
  #           "startTime"=>"2017-11-14T11:43:57.541+0000",
  #           "to"=>"sip:14437200257@sip-trunk-bandwidth.tropo.com",
  #           "endTime"=>"2017-11-14T11:44:18.657+0000",
  #           "applicationId"=>"5080983",
  #           "eventTimeStamp"=>1510659858661,
  #           "applicationName"=>"voxiplan IVR - STAGING",
  #           "direction"=>"in",
  #           "status"=>"Success"},
  #      "resource"=>"call",
  #      "name"=>"Tropo Webform Webhook",
  #      "id"=>"680a5110-693e-441e-b9e7-290c25e3643c",
  #      "event"=>"cdrCreated"}}
  def self.create_payload(params)
    data = params['data'].transform_keys{|k| k.underscore} rescue {}
    p = params.slice('resource', 'name', 'event').merge!(data.slice(*column_names))
    call = Call.find_by tropo_call_id: data[:call_id]


    if params['resource'] == 'sms' && data['label']
      client_id, to, call_id = data['label'].split(';').map{|v| v.split('=')[1]}
    end

    call = Call.find call_id if call_id.present?
    # elsif data['to'].present?
    #   # extract phone from sip 'sip:14437200257@sip-trunk-bandwidth.tropo.com'
    #   # phone = data['to'].split('@')[0].split(':')[1]
    #   phone = data['to'].match(/sip:(\w+)@/)[1]
    #   client_id = Client.where(phone: phone).or(Client.where(sip: data['to'])).take.try(:id)


    p.merge!(payload_id: params['id'], raw: params['webhook'], call: call, client_id: client_id)
    p[:to] = to if to.present? # For SMS
    p[:duration_minutes] = (data['duration']/60000.0).ceil if data['duration'].present?

    create(p)
  end

  def a(check = false)
    if check
      a, b= 1,2
    end
    puts a if a.present?
  end

end
