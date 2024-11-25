class GoogleSpeechToText
  def self.recognise(uri, locale)
    require "google/cloud/speech"

    return unless uri.present?
    locale ||= 'en-US'
    speech = Google::Cloud::Speech.speech#(version: :v1p1beta1)
    config = {
        encoding:          :LINEAR16,
        sample_rate_hertz: 8000,
        language_code: locale
    }
    config.merge!(use_enhanced: true, model: 'phone_call') if google_voice_enhanced(locale)

    begin
      audio_file  = open(uri) {|f| f.read }
      audio  = { content: audio_file }
      response = speech.recognize config: config, audio: audio
      puts "************ AUDIO URL: #{uri} "
      puts "************ Response from Google "
      puts response.inspect
      response.results[0].alternatives[0].transcript
    rescue StandardError => e
      puts "***************** Error while fetching text from speech: #{e.message}"
      puts e.backtrace
    end
  end

  def self.google_voice_enhanced(lang)
    %w[en-AU en-GB en-US fr-CA fr-FR ja-JP pt-BR ru-RU es-ES es-US].include? lang
  end
end

