class ClientNotifierMailer < ApplicationMailer
  include ApplicationHelper

  default :from => ENV['DEFAULT_EMAIL_FROM'], :reply_to => ENV['DEFAULT_EMAIL_FROM']

  def appointment_confirmation_mail(email, event_name, event_date_time, phone, cur_ivr, cancel_link, reschedule_link, reply_to_email)
    @phone = phone

    @event_name = event_name
    @event_date = l(event_date_time.to_date, format: :long, locale: cur_ivr.voice_locale)
    @event_time = event_date_time.strftime("%I:%M %p")
    @event_day = event_date_time.strftime("%A")
    @email_cancel_link = cancel_link
    @email_reschedule_link = reschedule_link

    @invalid_email_content = ''
    mail(:to => email, :subject => t("mails.confirmation.subject"), :reply_to => reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM'])

  end

  def appointment_confirmation_mail_invitee(email, event_name, event_date_time, phone, resource_name, cur_ivr, subject, body, cancel_link, reschedule_link)
    @phone = phone
    @full_name = cur_ivr.client.full_name
    @first_name = cur_ivr.client.first_name
    @last_name = cur_ivr.client.last_name

    @event_name = event_name
    @event_date = l(event_date_time.to_date, format: :long, locale: cur_ivr.voice_locale)
    @event_time = event_date_time.strftime("%I:%M %p")
    @event_day = event_date_time.strftime("%A")
    @resource_name = resource_name
    @email_subject = subject
    @email_body = body
    @email_cancel_link = cancel_link
    @email_reschedule_link = reschedule_link

    @invalid_email_content = ''
    mail(:to => email, :subject => subject, :reply_to => cur_ivr.client.email.presence || ENV['DEFAULT_EMAIL_FROM'])

  end

  def appointment_reschedule_confirmation_mail(email, event_name, event_date_time, phone, cur_ivr, reply_to_email)
    @phone = phone

    @event_name = event_name
    @event_date = l(event_date_time.to_date, format: :long, locale: cur_ivr.voice_locale)
    @event_time = event_date_time.strftime("%I:%M %p")
    @event_day = event_date_time.strftime("%A")

    @invalid_email_content = ''
    mail(:to => email, :subject => t("mails.confirmation.rescheduled_subject"), :reply_to => reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM'])

  end

  def appointment_reschedule_confirmation_mail_invitee(email, event_name, event_date_time, phone, resource_name, cur_ivr)
    @phone = phone
    @full_name = cur_ivr.client.full_name
    @first_name = cur_ivr.client.first_name
    @last_name = cur_ivr.client.last_name

    @event_name = event_name
    @event_date = l(event_date_time.to_date, format: :long, locale: cur_ivr.voice_locale)
    @event_time = event_date_time.strftime("%I:%M %p")
    @event_day = event_date_time.strftime("%A")
    @resource_name = resource_name
    @email_body = ''

    @invalid_email_content = ''
    mail(:to => email, :subject => t("mails.confirmation.rescheduled_subject"), :reply_to => cur_ivr.client.email.presence || ENV['DEFAULT_EMAIL_FROM'])

  end

  def appointment_pre_confirmation_mail(email, customer_email, start_formatted, phone, accept_url, decline_url, reply_to_email)
    @start_formatted, @phone, @accept_url, @decline_url, @customer_email = start_formatted, phone, accept_url, decline_url, customer_email

    @invalid_email_content = ''
    mail(:to => email, :subject => t("mails.pre_confirmation.subject"), :reply_to => reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM'])

  end

  def appointment_pre_confirmation_mail_invitee(email, start_formatted, phone, reply_to_email, subject, body)
    @start_formatted, @phone = start_formatted, phone
    @email_subject = subject
    @email_body = body

    @invalid_email_content = ''
    mail(:to => email, :subject => subject, :reply_to => reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM'])
  end

  def rejected_mail_invitee(email, start_formatted, reply_to_email)
    @start_formatted = start_formatted

    if is_invalid_email(email)
      @invalid_email_content = "Email type: Rejected email invitee, Email Address: #{email}"
      mail(to: ENV['ERROR_MAIL_RECIPIENTS'], subject: 'Fake invalid email address', reply_to: ENV['ERROR_MAIL_RECIPIENTS'])
    else
      @invalid_email_content = ''
      mail(:to => email, :subject => t("mails.rejected_invitee.subject"), :reply_to => reply_to_email.presence || ENV['DEFAULT_EMAIL_FROM'])
    end

  end

  def agenda_account_created(client)
    @client = client

    if is_invalid_email(client.email)
      @invalid_email_content = "Email type: agenda account created email, Email Address: #{client.email}"
      mail(to: ENV['ERROR_MAIL_RECIPIENTS'], subject: 'Fake invalid email address', reply_to: ENV['ERROR_MAIL_RECIPIENTS'])
    else
      @invalid_email_content = ''
      mail(:to => client.email, :subject => 'Your online agenda account is ready')
    end

  end

  # Available options
  # to: email_address to send an email
  # subject: subject of eamil
  # body: Body of email
  def generic_email(options = {})
    to = options[:to]
    subject = options[:subject]

    to.split(',').each do |email|
      if is_invalid_email(email)
        @invalid_email_content = "Email type: Generic email, Email Address: #{email}"
        mail(to: ENV['ERROR_MAIL_RECIPIENTS'], subject: 'Fake invalid email address', reply_to: ENV['ERROR_MAIL_RECIPIENTS'])
      else
        @invalid_email_content = options[:body]
        mail(to: email, subject: subject, reply_to: options[:reply_to_email].presence || ENV['DEFAULT_EMAIL_FROM'])
      end
    end
  end

  def no_availability_email(to_email)
    to = to_email
    subject = t("mails.no_availability.subject")
    @email_body = t("mails.no_availability.body")

    if is_invalid_email(to)
      @invalid_email_content = "Email type: No availability email, Email Address: #{to}"
      mail(to: ENV['ERROR_MAIL_RECIPIENTS'], subject: 'Fake invalid email address', reply_to: ENV['ERROR_MAIL_RECIPIENTS'])
    else
      mail(to: to, subject: subject)
    end
  end

  def organization_invitation_email(organization, to_email, id)
    to = to_email
    @organization_name = organization
    @link = ENV['DOMAIN'] + "/invitation/" + id.to_s

    mail(to: to, subject: t("mails.organization_invitation.subject"))
  end

  def generic_email_test(options = {})
    # options = {:to=>"shankar.yuvasoft15@gmail.com", :body=>"testing 123", subject:"generic_test"}
    to = options[:to]
    headers "X-SMTPAPI" => {
      "sub": { "%name%" => [to] },
      "filters": { "templates": { "settings": { "enable": 1, "template_id": "b9cb9b98-c384-4085-b198-f31a67afdd90" } } }
    }.to_json
    subject = options[:subject]
    @email_body = options[:body]
    mail(to: to, subject: subject)
  end

  def message_email(subject, body, to)
    @content = body

    mail(to: to, subject: subject)
  end
end
