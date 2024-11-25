class TwilioUpdateCallsJob < ApplicationJob
  queue_as :twilio

  def perform(start_time, end_time)
    start_time = Date.parse(start_time)
    end_time = Date.parse(end_time)

    begin
      calls = TwilioEngine.client.calls.list(start_time_after: start_time, start_time_before: end_time)

      incoming_calls = calls.select {|c| c.direction == 'inbound' }
      update_incoming_calls(incoming_calls)

      outgoing_calls = calls.select{|c| c.direction == 'outbound-dial'}
      update_outgoing_calls(outgoing_calls)

      sip_calls = calls.select { |c| c.from.include? 'sip:'}
      update_sip_calls(sip_calls)

      messages = TwilioEngine.client.messages.list(date_sent_after: start_time, date_sent_before: end_time)
      incoming_messages = messages.select {|c| c.direction == 'inbound' }
      update_incoming_messages(incoming_messages)

      outgoing_messages = messages.select{|c| c.direction == 'outbound-api'}
      update_outgoing_messages(outgoing_messages)

      phone_list = PhoneNumber.where("created_at BETWEEN ? AND ?", start_time, end_time)
      phones = phone_list.select{ |p| p }
      update_phone_info(phones)

    rescue Exception => e
      logger.error "XXXXXX Exception while Updating Calls from Twilio"
      puts e.message
      puts e.backtrace
    end
  end

  def update_incoming_calls(incoming_calls)
    incoming_calls.each do |call|
      local_call = Call.find_by(tropo_call_id: call.sid)
      next unless local_call

      margin = get_margin(local_call)
      phone = Phonelib.parse(call.from)
      local_call.finished_at ||= call.end_time
      local_call.duration ||= call.duration
      local_call.call_type ||= 'incoming'

      if phone.type == :mobile || phone.type == :fixed_or_mobile
        local_call.phone_type ||= 'mobile'
        local_call.margin = margin[:voice_inbound_mobile]
        local_call.sale_price = call.price.to_f.abs * margin[:voice_inbound_mobile]
      end

      if phone.type == :fixed_line
        local_call.phone_type ||= 'local'
        local_call.margin = margin[:voice_inbound_local]
        local_call.sale_price = call.price.to_f.abs * margin[:voice_inbound_local]
      end
      local_call.phone_price = call.price.to_f.abs

      local_call.save
    end
  end

  def update_outgoing_calls(outgoing_calls)
    outgoing_calls.each do |call|
      next unless Call.find_by(tropo_call_id: call.parent_call_sid)

      local_call = Call.find_or_create_by(tropo_call_id: call.sid)
      margin = get_margin(local_call)

      local_call.created_at = call.start_time
      local_call.finished_at = call.end_time
      local_call.call_type = 'outgoing'

      local_call.duration = call.duration
      local_call.forwarded_from = call.forwarded_from
      local_call.from = call.from
      local_call.parent_call_sid = call.parent_call_sid
      local_call.phone_price = call.price.to_f.abs
      local_call.margin = margin[:voice_outbound]
      local_call.sale_price = call.price.to_f.abs * margin[:voice_outbound]
      local_call.save
    end
  end

  def update_sip_calls(sip_calls)
    sip_calls.each do |call|
      local_call = Call.find_by(tropo_call_id: call.sid)
      next unless local_call

      margin = get_margin(local_call)
      local_call.is_sip = true
      local_call.phone_price = call.price.to_f.abs
      local_call.margin = margin[:sip]
      local_call.sale_price = call.price.to_f.abs * margin[:sip]
      local_call.save
    end
  end

  def update_incoming_messages(incoming_messages)
    incoming_messages.each do |message|
      local_message = TextMessage.find_by(sid: message.sid)
      next unless local_message

      margin = get_margin(local_message)
      local_message.segment = message.num_segments
      local_message.sms_price = message.price.to_f.abs
      local_message.incoming = true
      local_message.is_twilio = true
      local_message.margin = margin[:sms_inbound]
      local_message.sale_price = message.price.to_f.abs * margin[:sms_inbound]
      local_message.save
    end
  end

  def update_outgoing_messages(outgoing_messages)
    outgoing_messages.each do |message|
      local_message = TextMessage.find_by(sid: message.sid)
      next unless local_message

      margin = get_margin(local_message)
      local_message.segment = message.num_segments
      local_message.sms_price = message.price.to_f.abs
      local_message.is_twilio = true
      local_message.incoming = false
      local_message.margin = margin[:sms_outbound]
      local_message.sale_price = message.price.to_f.abs * margin[:sms_outbound]
      local_message.save
    end
  end

  def update_phone_info(phones)
    phones.each do |phone|
      id = Identifier.find_by_identifier(phone.number.gsub('+', ''))
      next unless id
      next if id.phone_price.present?

      phone_info = twilioclient.lookups.v1.phone_numbers(phone.number).fetch(type: ['carrier'])
      phone_country_code = phone_info.country_code
      phone_type = phone_info.carrier['type']
      phone_type = 'local' if phone_type == 'landline' || phone_type.nil?

      pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))
      phone_data = pricing_details.symbolize_keys[:phone_number]

      default_phone_margin = fetch_phone_margin(phone_data)
      user_phone_margin = nil
      user_phone_margin = fetch_phone_margin(phone_data[country_code]) if phone_data.include? phone_country_code

      phone_margin = user_phone_margin.nil? || user_phone_margin[:local].nil? ? default_phone_margin[:local] : user_phone_margin[:local] if phone_type == 'local'
      phone_margin = user_phone_margin.nil? || user_phone_margin[:mobile].nil? ? default_phone_margin[:mobile] : user_phone_margin[:mobile] if phone_type == 'mobile'
      phone_margin = user_phone_margin.nil? || user_phone_margin[:national].nil? ? default_phone_margin[:national] : user_phone_margin[:national] if phone_type == 'national'

      phone_margin = fetch_margin_val(phone_margin.to_i)
      twilio_price = 0
      phone_prices = twilioclient.pricing.v1.phone_numbers.countries(phone_country_code).fetch
      (phone_prices&.phone_number_prices || []).each do |data|
        twilio_price = data['base_price'].to_f if data['number_type'] == phone_type
      end
      id.phone_type = phone_type
      id.phone_price = (twilio_price * phone_margin).round(2)
      id.save
    end
  end

  def get_margin(call)
    user_country_code = 'fr'
    user_country_code = call.ivr.client.country_code.downcase if call.ivr_id.present?
    if call.ivr_id.nil?
      phone = Phonelib.parse(call.from)
      user_country_code = phone.country_code.downcase
    end

    pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))

    sip_data = pricing_details.symbolize_keys[:sip]
    voice_data = pricing_details.symbolize_keys[:voice]
    sms_data = pricing_details.symbolize_keys[:sms]
    phone_data = pricing_details.symbolize_keys[:phone_number]

    # get margin for voice
    default_voice_margin = fetch_voice_margin(voice_data)
    user_voice_margin = nil
    user_voice_margin = fetch_voice_margin(voice_data[user_country_code]) if voice_data.include? user_country_code

    voice_inbound_local_margin = user_voice_margin.nil? || user_voice_margin[:inbound_local].nil? ? default_voice_margin[:inbound_local] : user_voice_margin[:inbound_local]
    voice_inbound_mobile_margin = user_voice_margin.nil? || user_voice_margin[:inbound_mobile].nil? ? default_voice_margin[:inbound_mobile] : user_voice_margin[:inbound_mobile]
    voice_outbound_margin = user_voice_margin.nil? || user_voice_margin[:outbound].nil? ? default_voice_margin[:outbound] : user_voice_margin[:outbound]
    voice_inbound_local_margin = fetch_margin_val(voice_inbound_local_margin.to_i)
    voice_inbound_mobile_margin = fetch_margin_val(voice_inbound_mobile_margin.to_i)
    voice_outbound_margin = fetch_margin_val(voice_outbound_margin.to_i)

    # get margin for sms
    default_sms_margin = fetch_sms_margin(sms_data)
    user_sms_margin = nil
    user_sms_margin = fetch_sms_margin(sms_data[user_country_code]) if sms_data.include? user_country_code

    sms_inbound_margin = user_sms_margin.nil? || user_sms_margin[:inbound].nil? ? default_sms_margin[:inbound] : user_sms_margin[:inbound]
    sms_outbound_margin = user_sms_margin.nil? || user_sms_margin[:outbound].nil? ? default_sms_margin[:outbound] : user_sms_margin[:outbound]
    sms_inbound_margin = fetch_margin_val(sms_inbound_margin.to_i)
    sms_outbound_margin = fetch_margin_val(sms_outbound_margin.to_i)

    # get margin for phone number
    default_phone_margin =  fetch_phone_margin(phone_data)
    user_phone_margin = nil
    user_phone_margin = fetch_phone_margin(phone_data[user_country_code]) if phone_data.include? user_country_code

    phone_national_margin = user_phone_margin.nil? || user_phone_margin[:national].nil? ? default_phone_margin[:national] : user_phone_margin[:national]
    phone_local_margin = user_phone_margin.nil? || user_phone_margin[:local].nil? ? default_phone_margin[:local] : user_phone_margin[:local]
    phone_mobile_margin = user_phone_margin.nil? || user_phone_margin[:mobile].nil? ? default_phone_margin[:mobile] : user_phone_margin[:mobile]
    phone_national_margin = fetch_margin_val(phone_national_margin.to_i)
    phone_local_margin = fetch_margin_val(phone_local_margin.to_i)
    phone_mobile_margin = fetch_margin_val(phone_mobile_margin.to_i)

    # get margin for SIP
    sip_margin = sip_data.include?(user_country_code) ? fetch_margin_val(sip_data[user_country_code].to_i) : fetch_margin_val(sip_data[:margin].to_i)

    {
      voice_inbound_local: voice_inbound_local_margin,
      voice_inbound_mobile: voice_inbound_mobile_margin,
      voice_outbound: voice_outbound_margin,
      sms_inbound: sms_inbound_margin,
      sms_outbound: sms_outbound_margin,
      phone_national: phone_national_margin,
      phone_local: phone_local_margin,
      phone_mobile: phone_mobile_margin,
      sip: sip_margin
    }
  end
end

