class IncomingSmsReplyJob < ApplicationJob
  queue_as :default

  def perform(msg_id)
    begin
      msg = TextMessage.find(msg_id)
      # Use only if different Rasa server for each language
      # reply_text = RasaParty.new(msg.conversation.session_id, msg.ivr.message_locale).chat(message: msg.content)
      reply_text = RasaParty.new(msg.conversation.session_id, msg.ivr.assistant_name, msg.ivr.message_locale[0..1], msg.ivr.preference['widget_tz'], "#{msg.ivr.message_locale}-#{msg.ivr.client.country_code}", "sms").chat(message: msg.content)

      reply = TextMessage.create(
        to: msg.from,
        content: reply_text,
        sms_type: 'ai_bot',
        ivr: msg.ivr
      )

      # debugger

      if msg&.ivr.voxi_sms?
        VoxiSMSJob.perform_later(reply.id)
      else
        TwilioSMSJob.perform_later(reply.id)
      end

    rescue Exception => e
      logger.error "XXXXXX Exception while replying incoming sms"
      puts e.message
      puts e.backtrace
    end
  end
end
