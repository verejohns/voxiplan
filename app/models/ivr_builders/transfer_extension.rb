class TransferExtension < IvrBuilder
  def ext_action
    'ext_action_transfer_call'
  end

  def build
    voice_email = VoiceToEmail.new(@ivr, prefix: prefix).build
    create(
      Transfer, name('transfer'),
      ext_options.merge(
        {
          text: t('static_ivr.your_call_being_transfer'),
          users: default_users, from: "%{caller_id}",
          next: voice_email
        })
    ).name
  end
end