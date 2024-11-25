class StaticIvr < IvrBuilder
  # Build nodes and return starting point
  def build
    # TODO: Write rake task to set caller_id as start_node instead of business_hours
    start_node = 'business_hours'
    create(BusinessHours, 'business_hours',
           business_hours:
             {mon: [{from: '09:00', to: '17:00'}],
              tue: [{from: '09:00', to: '17:00'}],
              wed: [{from: '09:00', to: '17:00'}],
              thu: [{from: '09:00', to: '17:00'}],
              fri: [{from: '09:00', to: '17:00'}]
             },
           next: 'welcome_open', invalid_next: 'welcome_closed'
    )

    create(Say, 'welcome_open', text: t('static_ivr.welcome_open'), next: 'check_caller_id', context: welcome_context)
    create(Say, 'welcome_closed', text: t('static_ivr.welcome_closed'), next: 'check_caller_id', context: welcome_context)

    create(Conditional, 'announcement_wrt_business_hours',
           left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
           next: 'announcement_open', invalid_next: 'announcement_closed')

    create(Say, 'announcement_open', text: t('static_ivr.announcement_open'), next: 'menu_open', enabled: false, can_enable: true, context: announcement_context)
    create(Say, 'announcement_closed', text: t('static_ivr.announcement_closed'), next: 'menu_closed', enabled: false, can_enable: true, context: announcement_context)

    appointment_bot = AppointmentBot.build(@ivr, @options)
    transfer_extension1 = TransferExtension.new(@ivr, prefix: @ivr.next_extension, title: 'Extension 1').build
    transfer_extension2 = TransferExtension.new(@ivr, prefix: @ivr.next_extension, title: 'Extension Closed 1').build

    # This VoiceToEmail is used on many places it start node is voice_to_email_record
    # transfer_or_voicemail = VoiceToEmail(start: voice_to_email_record) + transfer_to_agent)
    VoiceToEmail.new(@ivr, prefix: 'voice_to_email', record_file_name: 'closed_message_record').build
    # transfer_extension2 = TransferExtension.new(@ivr, prefix: @ivr.next_extension, title: 'Extension 2').build

    create(Menu, 'menu_open', text: t('static_ivr.menu_open'),
           timeout: 5,
           timeout_next: 'timeout', invalid_next: 'invalid',
           choices: {key_1: appointment_bot, key_2: transfer_extension1},
           next: appointment_bot,
           context: menu_open_context)

    create(Menu, 'menu_closed', text: t('static_ivr.menu_closed'),
           timeout: 5,
           timeout_next: 'timeout', invalid_next: 'invalid',
           choices: {key_1: appointment_bot, key_2: transfer_extension2},
           next: appointment_bot,
           context: menu_closed_context)

    create(Say, 'timeout', text: t('static_ivr.timeout'), next: 'transfer_or_voicemail', enabled: true, can_enable: true)
    create(Say, 'invalid', text: t('static_ivr.invalid'), next: 'transfer_or_voicemail', enabled: true, can_enable: true)
    create(Say, 'internal_error', text: t('static_ivr.internal_error'), next: 'transfer_or_voicemail', enabled: true, can_enable: true)

    create(SendEmail, 'hangup_mail', users: default_users,
           text: {
               title: I18n.t("mails.client_call_hangup.title"),
               greetings: I18n.t("mails.client_call_hangup.greetings"),
               summary: I18n.t("mails.client_call_hangup.summary"),
               copyright: I18n.t("mails.copyright"),
               reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us"),
           },
           email_subject: t('static_ivr.call_hangup_mail_subject'),
           parameters: {
               template_id: 'd-c0fd6aeab47340f5b7800eeaf536fc50',
           },
           next: 'hangup_caller_sms')

    create(SendSMS, 'hangup_caller_sms', to: "%{caller_id}",
           text: t('static_ivr.hangup_caller_sms'), enabled: false,
           next: 'hang')

    create(Hangup,'hang', text: 'Thank you')

    start_node
  end

  def welcome_context
    [
      {msg: t('static_ivr.menu_open'), input: 1},
      {msg: t('static_ivr.gather_number'), input: "19298090#"},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end

  def announcement_context
    [
      {msg: t('static_ivr.gather_number'), input: "19298090#"},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end

  def menu_open_context
    [
      {msg: t('static_ivr.appointment_announcement_open'), input: 1},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end

  def menu_closed_context
    [
      {msg: t('static_ivr.appointment_announcement_closed'), input: 1},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end
end