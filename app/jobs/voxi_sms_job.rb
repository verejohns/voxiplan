class VoxiSMSJob < ApplicationJob
  queue_as :default

  def perform(sms_id)
    sms = TextMessage.find(sms_id)
    customer_id, secret = sms.ivr.preference.values_at('voxi_sms_customer_id', 'voxi_sms_secret')
    opts = {
        message: sms.content,
        recipient: sms.to,
        id: sms.uuid,
    }
    puts "VoxiSMS APi Call"
    puts "customer_id: #{customer_id}, params: #{opts}"

    begin
      response = VoxiSMSParty.new(customer_id, secret, sms.uuid).send_msg(opts)

    rescue Exception => e
      logger.error "XXXXXX Exception while calling API."
      puts e.message
      puts e.backtrace
      sms.update(error_message: e.message)
    end

    puts "=== API CAll response: #{response.inspect}"
  end
end
