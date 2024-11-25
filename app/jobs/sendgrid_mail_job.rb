require 'sendgrid-ruby'

class SendgridMailJob < ApplicationJob
  queue_as :default
  include SendGrid

  def perform(json_mail_payload)
    puts "Going to send email"
    puts json_mail_payload
    data = json_mail_payload['personalizations'][0]['dynamic_template_data']
    ActiveRecord::Base.connection_pool.with_connection do
      recording = recording(data['play_recording_btn_url'])
      if recording && recording.url
        locale = recording.call.try(:ivr).try(:voice_locale)
        google_voice_locale = recording.call.try(:ivr).try(:google_voice_locale)
        data['transcription_title'] = I18n.t('mails.transcription_title', locale: locale )
        data['transcription_text'] = GoogleSpeechToText.recognise(recording.url, google_voice_locale)
      else
        # we are hiding button based on this
        data['play_recording_btn_url'] = nil
      end
    end

    puts "*********** end email **** "
    sg = SendGrid::API.new(api_key: ENV['SENDGRID_PASSWORD'])
    begin
      response = sg.client.mail._("send").post(request_body: json_mail_payload)
    rescue Exception => e
      logger.error "XXXXXX Exception while sending email."
      puts e.message
      puts e.backtrace
    end

    puts "response.status_code: #{response.status_code}"
  end

  def recording(voxi_url)
    return unless voxi_url
    recording_id = voxi_url.split('/').last
    Recording.find_by uuid: recording_id
  end
end

