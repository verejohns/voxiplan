class BotGather < TelephonyNode

  def execute
    if @options.delete(:parse_response)
      handle_response
    else
      puts "******** hints: #{data[:hints]}"
      self.text = data[:bot_says]
      if ['/goodbye','See you soon.','À bientôt.'].include? self.text
        puts '*********--------- Hangup call for RASA ---------*********'
        telephony.say(self.text)
        telephony.hangup
      else
        tts_voice = TelephonyEngine.voices.find { |v| v[:locale] == self.ivr.voice_locale.to_s && v[:voice] == self.ivr.voice.to_s}
        tts_voice = TelephonyEngine.voices.find { |v| v[:locale] == self.ivr.message_locale.to_s && v[:voice] == self.ivr.message.to_s} if self.ivr.preference['only_ai']

        telephony.gather(language: tts_voice[:locale] || 'en-US', input: 'speech dtmf', speechModel: 'phone_call', enhanced: 'true', speechTimeout: 3, hints: data[:hints], numDigits: nil)
      end
        # telephony.gather(input: 'speech dtmf', speechTimeout: 'auto', hints: data[:hints], numDigits: nil)
    end
  end

  def handle_response
    speech_result = telephony.get_response[:speech_result]
    speech_result = telephony.get_response[:value] unless speech_result
    puts "***** speech result #{speech_result}"
    save_data(speech_result, key: 'user_says') if speech_result

    if timeout? || data[:user_says].blank?
      data[:bot_timeout_tries_count] ||= 1
      # if self.tries == 1 || (data[:timeout_tries_count] > (self.tries))
      if data[:bot_timeout_tries_count] >= (self.tries || 3)
        data[:bot_timeout_tries_count] = nil
        data[:user_says] = '/timeout'
      else
        data[:bot_timeout_tries_count] += 1
        # run gather again
        return self.run(@options)
      end
    end

    next_node.run(@options)
  end
end
