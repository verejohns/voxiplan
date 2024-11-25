# override gem method and do not convert to SSML if SSMD is not used
module SSMD
  class Converter
    def convert
      result = processors.inject(input.encode(xml: :text)) do |text, processor|
        process processor.new(processor_options), text
      end

      result == input.encode(xml: :text) ? input : "<speak>#{(result.strip)}</speak>"
    end
  end
end

class TwilioEngine < TelephonyEngine
  EXCEPTION_NUMBERS = ['737 874-2833', '7378742833', '+7378742833',
                       '256-2533', '2562533', '+2562533',
                       '865-6696', '8656696', '+8656696',
                       '266696687', '+266696687',
                       '86282452253', '+86282452253', nil]

  def say(text = nil)
    if node.ivr.play_enabled?
      twilio.play(url: load_audio_file(to_ssml(text || ' '))) unless text.blank?
    else
      ssml_content = say_options(message: text)
      ssml_content[:message] = ssml_content[:message].gsub('<speak>', '')

      twilio.say ssml_content
    end
    set_next_node
    twilio
  end

  def menu(options = {})
    # options[:hints] ||= node.choices.keys.map{|k| k[-1]}.join(', ')
    options[:numDigits] ||= 1
    gather(options)
  end

  def gather_number
    gather
  end

  def gather(overides = {})
    action = next_node_path(node, parse_response: true)
    twilio.gather(ask_params.merge(action: action).merge(overides)) do |gather|
      if node.ivr.play_enabled?
        gather.play(url: load_audio_file(to_ssml(node.text || ' '))) unless node.text.blank?
      else
        gather.say say_options
      end
    end
    if node.try1_timeout_node.present?
      if node.ivr.play_enabled?
        twilio.play(url: load_audio_file(to_ssml(node.try1_timeout_node.text || ' '))) unless node.try1_timeout_node.text.blank?
      else
        twilio.say say_options(message: node.try1_timeout_node.text)
      end
    end
    set_next_node(node, parse_response: true, Digits: 'TIMEOUT')
    twilio
  end


  def transfer(to, from, text = '')
    if node.ivr.play_enabled?
      twilio.play(url: load_audio_file(to_ssml(text || ' '))) unless text.blank?
    else
      twilio.say say_options(message: text)
    end
    dial_params = {caller_id: format_num(from), timeout: node.timeout}.compact
    twilio.dial(dial_params) do |dial|
      to.each do |x|
        if x.include?('@')
          # do not dial sip for now
          # dial.sip format_sip(x)
        else
          dial.number format_num(x)
        end
      end
    end
    twilio
  end

  def record(text, url)
    action = next_node_path(node, parse_response: true)
    if node.ivr.play_enabled?
      twilio.play(url: load_audio_file(to_ssml(text || ' '))) unless text.blank?
    else
      twilio.say say_options(message: text)
    end
    twilio.record(action: action, recording_status_callback: url)
    set_next_node(node, parse_response: true)
    twilio
  end

  def send_sms(sms_id)
    TwilioSMSJob.perform_later(sms_id)
  end

  def get_response
    return node.test_input if node.test_input
    return OpenStruct.new unless twilio_response
    # TODO: return timeout
    OpenStruct.new(value: twilio_response[:Digits],
                   speech_result: twilio_response[:SpeechResult],
                   disposition: twilio_response[:Digits],
                   url: twilio_response[:RecordingUrl],
                   call_status: twilio_response[:CallStatus],
                   upload_status: 'success')
  end

  def set_next_node(node = @node.next_node, params={})
    twilio.redirect(next_node_path(node, params))
  end

  def ask_params
    {
        # name: node.name, Twilio returns response in params[:Digits]
        # say: say_objects,
        # say: to_ssml(node.text), # TODO: Think about timeouts
        timeout: node.timeout,
        input: 'dtmf',
        numDigits: node.input_max_length
        # attempts: node.tries || 2,
        # required: node.required.nil? ? true : node.required,
        # bargein: node.interruptible.nil? ? true : node.interruptible,
    }.compact
  end

  def hints(value)
    {
        hints: value
    }
  end

  def gather_number_choice_value
    # if node.input_min_length && node.input_max_length
    #   "[#{node.input_min_length}-#{node.input_max_length} DIGITS]"
    # else
    #   "#{node.input_min_length || node.input_max_length} DIGIts"
    # end
  end

  # def say_objects
  #   say = []
  #   say << { value: to_ssml(node.try1_invalid_node.text), event: 'nomatch'} if node.try1_invalid_node.present?
  #   say << { value: to_ssml(node.try1_timeout_node.text), event: 'timeout'} if node.try1_timeout_node.present?
  #   say << { value: to_ssml(node.text) }
  #   say
  # end

  def twilio
    @twilio ||= Twilio::TwiML::VoiceResponse.new
  end

  def twilio_response
    @options[:tropo_session]
  end

  def hangup
    twilio.hangup
  end

  private

  def say_options(options = {})
    options[:message] = to_ssml(options[:message] || node.text)
    default_options.merge(options).compact
  end

  def load_audio_file(audio_text)
    file_name = "tmp/#{node.id.to_s + '_' + node.name}.wav"
    create_file_for_tts(audio_text, file_name, node.ivr)
    file_url = upload_file_for_tts(file_name)
    file_url
  end

  def default_options
    {voice: node.ivr.preference['only_ai'] ? node.ivr.message : node.ivr.voice, language: node.ivr.preference['only_ai'] ? node.ivr.message_locale : node.ivr.voice_locale}
  end

  def format_sip(str)
    return str if str.starts_with?('sip:')
    str.prepend('sip:')
  end

  def format_num(str)
    TwilioEngine.format_num(str)
  end

  def self.isAlphanumeric? str
    str.strip.match?(/^[a-zA-Z]/)
  end

  def self.format_num(str)
    return nil unless str.present?
    return str if str.starts_with?('+')
    return str if isAlphanumeric?(str)
    "+#{str}"
  end

  def to_ssml(text)
    return SSMD.strip_ssmd(text) unless support_ssml?
    SSMD.to_ssml text
  end

  def support_ssml?
    default_options[:voice].match(/Polly/)
  end

  def self.reject
      '<?xml version="1.0" encoding="UTF-8"?>
      <Response>
          <Reject />
      </Response>'
  end

  def create_file_for_tts(text_wording, file_name, lang_details)
    client = Google::Cloud::TextToSpeech.text_to_speech

    synthesis_input = { text: text_wording }
    # ssml = SSMD.to_ssml(text_wording)
    # input_text = { ssml: ssml }
    google_voice = TelephonyEngine.voices.find { |v| v[:locale] == lang_details.voice_locale.to_s && v[:voice] == lang_details.voice.to_s}
    google_voice = TelephonyEngine.voices.find { |v| v[:locale] == lang_details.message_locale.to_s && v[:voice] == lang_details.message.to_s} if lang_details.preference['only_ai']

    voice = {
      language_code: google_voice[:locale], #'en-IN',#lang_code, # to be passed from client selection
      ssml_gender:   google_voice[:gender], #'FEMALE',#lang_ssml # to be passed from client selection
      name:          google_voice[:voice] #'en-IN-Wavenet-D'
    }

    # voices = client.list_voices({}).voices

    audio_config = { audio_encoding: 'MP3'}

    puts "-----------  twilio input ------------"
    puts synthesis_input

    puts "------------ twilio voice -------------"
    puts voice

    response = client.synthesize_speech(
      input:        synthesis_input,
      # input:        input_text,
      # voice:        voices[0],
      voice:        voice,
      audio_config: audio_config
    )

    File.open file_name, 'wb' do |file|
      file.write response.audio_content
    end
  rescue => e
    puts "****** create_file_for_tts error ********"
    puts e.message
  end

  def upload_file_for_tts(file_name)
    s3_inst = Aws::S3::Resource.new(region: (ENV['AWS_REGION']).to_s)

    bucket = ENV['S3_BUCKET_NAME']

    name = File.basename(file_name)

    obj = s3_inst.bucket(bucket).object(name)

    obj.upload_file(file_name, content_type: 'audio/mpeg')

    obj.public_url
  end

  # Available options:
  # https://www.twilio.com/docs/voice/sip/api/sip-domain-resource?code-sample=code-read-domain&code-language=Ruby&code-sdk-version=5.x
  # prerequisite:
  # set your SID in your ENV
  # Example:
  # TwilioEngine.update_sip(voice_url: 'https://15dbbae4.ngrok.io/run')
  def self.update_sip(options = {})
    client.sip.domains(ENV['SID']).update(options)
  end

  # TwilioEngine.update_num(voice_url: 'https://53513f05.ngrok.io/run')
  def self.update_num(options = {})
    client.incoming_phone_numbers(ENV['SID']).update(options)
  end

  # TwilioEngine.update_num(voice_url: 'https://53513f05.ngrok.io/run')
  def self.update_num_url(sid,options = {})
    client.incoming_phone_numbers(sid).update(options)
  end

  def self.update_sip_url(sid,options = {})
    client.sip.domains(sid).update(options)
  end

  def self.add_sip_url(options = {})
    client.sip.domains.create(options)
  end

  def self.client
    @client ||= Twilio::REST::Client.new(ENV['ACCOUNT_SID'] ,ENV['AUTH_TOKEN'])
  end

  # Available options
  # :body
  # :from
  # :to
  def self.send_sms(options)
    options[:to]   = format_num(options[:to])
    options[:from] = format_num(options[:from])
    client.messages.create(options)
  end

end