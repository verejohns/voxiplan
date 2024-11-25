class SendEmail < Node
  def execute
    emails = self.users.map(&:email)
    emails << self.to
    emails << notifiable_user_emails if client_email?
    emails = emails.flatten.compact.uniq.presence || [default_user.email]
    emails.each do |email|
      subj = self.email_subject.is_a?(String) ? self.email_subject : self.email_subject['en']
      dup_data[:caller_id] = 'Unknown' if dup_data[:caller_id].blank? || TwilioEngine::EXCEPTION_NUMBERS.include?(dup_data[:caller_id])
      caller_id_with_code = Phonelib.parse(dup_data[:caller_id]).to_s if dup_data[:caller_id] != 'Unknown'
      mail_ivr = Ivr.find(dup_data[:current_ivr_id]) if dup_data[:current_ivr_id].present?
      dup_data[:email_full_name] = mail_ivr.client.contacts.find_by_phone(caller_id_with_code).try(:customer).try(:full_name) if caller_id_with_code.present? and mail_ivr
      dup_data[:email_contact_type] = dup_data[:email_full_name] ? 'Returning' : 'New'
      template_data = self.text.transform_values{|p| p % dup_data rescue '' }
      options = {to: email, template_id: self.parameters['template_id'], template_data: template_data.merge(subject: subj), subject: subj}
      SendgridMailJob.set(wait: 30.seconds).perform_later SendgridMail.payload(options)
    end
    next_node.try(:run, @options)
  end


  # if true would say internal error on
  def exit_on_error?
    false
  end

  # HACK: As quick fix to notify all users we used this condition.
  def client_email?
    %w[hangup_mail appointment_success_mail voice_to_email_email].include?(name) ||
      name.match?(/extension_/)
  end

  def notifiable_user_emails
    # OPTIMIZE: Add boolean db field to users to determine if notifications are enabled
    ivr.nodes.where(name: 'transfer_to_agent').first.users.pluck(:email)
  end
end