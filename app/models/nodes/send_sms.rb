class SendSMS < Node
  def execute
    if self.ivr.confirmation_sms? && phones.present? && !exception_number?
      phones.each do |phone|
        if is_valid_mobile(phone)
          sms = create_sms(phone)
          telephony.send_sms(sms.id) if sms.persisted?
        end
      end
    end

    next_node.try(:run, @options)
  end

  def telephony_name
    self.ivr.preference['sms_engin'] || 'twilio'
  end

  def phones
    phones = self.users.map(&:number)
    phones << interpolated_value(self.to)
    phones << notifiable_user_phones if client_sms?

    phones.flatten.compact.uniq.presence || [default_user.number]
  end

  # if true would say internal error on
  def exit_on_error?
    false
  end

  private

  def exception_number?
    # only handle caller_sms
    return false unless name == 'hangup_caller_sms'
    ivr.find_node('check_caller_id').right_operand.include?(data[:caller_id]) rescue false
  end

  def is_valid_mobile(phone_no)
    phone = Phonelib.parse(phone_no)
    (phone.types.include?(:fixed_or_mobile) or phone.types.include?(:mobile)) rescue false
  end

  def create_sms(phone)
    sms_text = interpolated_text

    opts = {
        to: Phonelib.parse(phone).e164,
        content: sms_text.dup,
        call_id: data[:current_call_id],
        sms_type: self.name,
        ivr: self.ivr
    }
    TextMessage.create(opts)
  end

  def client_sms?
    %w[hangup_caller_sms appointment_success_client_sms].include?(name)
  end

  def notifiable_user_phones
    # OPTIMIZE: Add boolean db field to users to determine if notifications are enabled
    ivr.nodes.where(name: 'transfer_to_agent').first.users.map(&:number)
  end
end