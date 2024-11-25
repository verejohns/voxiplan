class TwilioSMSJob < ApplicationJob
  queue_as :default

  def perform(sms_id)
    sms = TextMessage.find(sms_id)

    identifers = sms.ivr.identifiers.pluck(:identifier).map{|i| "+#{i}" if i.scan(/\D/).empty?}.compact
    phone_number = PhoneNumber.where(number: identifers,sms: true).try(:first).try(:number)

    opts = {
        body: sms.content,
        to: sms.to,
        from: sms.ivr.preference['sms_from'].to_s.presence || phone_number.to_s.presence || ENV['TWILIO_DEFAULT_SMS_FROM'],
        status_callback: "#{ENV['DOMAIN']}/sms?iid=#{sms.ivr.id}"
    }
    puts "Twilio SMS snding"
    puts opts

    begin
      response = TwilioEngine.send_sms(opts)
      sms.update(sid: response.sid)
    rescue Exception => e
      logger.error "XXXXXX Exception while sending SMS through Twilio."
      puts e.message
      puts e.backtrace
      sms.update(error_message: e.message)
    end

    puts "=== Twilio API CAll response: #{response.inspect}"
  end
end
