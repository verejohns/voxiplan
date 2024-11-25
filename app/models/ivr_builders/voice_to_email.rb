class VoiceToEmail < IvrBuilder
  def ext_action
    'ext_action_send_to_voicemail'
  end

  def build
    record_node = name('record')
    email_node = name('email')

    start = create(Record, record_node,
                   ext_options.merge(
                     {
                       text: t('static_ivr.record_your_message'),
                       parameters: {file_name: @options[:record_file_name]},
                       next: email_node
                     }))

    create(SendEmail, email_node,
           users: default_users,
           text: {
               title: I18n.t("mails.client_new_voicemail.title"),
               greetings: I18n.t("mails.client_new_voicemail.greetings"),
               summary: I18n.t("mails.client_new_voicemail.summary"),
               play_recording_btn_text: I18n.t("mails.client_new_voicemail.play_recording_btn_text"),
               play_recording_btn_url: I18n.t("mails.client_new_voicemail.play_recording_btn_url", var: record_node),
               copyright: I18n.t("mails.copyright"),
               reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us"),
           },
           email_subject: t('static_ivr.voice_mail_subject'),
           parameters: {
               template_id: 'd-38647bf26a8648c8bb52193b61a1982e',
           },
           next: 'hang')
    start.name
  end
end
