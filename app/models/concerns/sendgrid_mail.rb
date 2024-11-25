require 'sendgrid-ruby'

class SendgridMail

  class << self
    include SendGrid

    def payload(options)
      mail = Mail.new
      mail.from = options[:from] || default_from_address
      mail.subject = options[:subject]
      mail.reply_to = Email.new(email: options[:reply_to_email], name: options[:reply_to_name]) if options[:reply_to_email]
      personalization = Personalization.new
      personalization.add_to(Email.new(email: options[:to]))
      personalization.add_bcc(Email.new(email: ENV["MAIL_BCC"])) if ENV['MAIL_BCC'] && ENV['MAIL_BCC'] != options[:to]
      personalization.subject = options[:subject]
      personalization.add_dynamic_template_data(options[:template_data])
      mail.add_personalization(personalization)
      mail.template_id = options[:template_id]
      mail.to_json
    end

    private

    def default_from_address
      Email.new(email: ENV['DEFAULT_EMAIL_FROM'].presence || 'info@voxiplan.com')
    end
  end

end