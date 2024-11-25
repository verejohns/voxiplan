module SettingsHelper

  def extension_options(menu, current_action)
    opts = [
      [I18n.t('static_ivr.ext_action_transfer_call'), 'ext_action_transfer_call'],
      [I18n.t('static_ivr.ext_action_send_to_voicemail'), 'ext_action_send_to_voicemail'],
      [I18n.t('static_ivr.ext_action_say_message'), 'ext_action_say_message'],
    ]

    opts.prepend [I18n.t('static_ivr.ext_action_appointment_bot'), 'ext_action_appointment_bot'] if !menu.choices.values.include?(AppointmentBot::START) || current_action == 'ext_action_appointment_bot'
    opts
  end

  def ext_users(node)
    if node.ext_action == 'ext_action_send_to_voicemail'
      # Todo improve.
      node.next_node.users
    else
      node.users
    end
  end

  def ext_users_names(node)
    ext_users(node).map(&:name).join("<br>").html_safe rescue ""
  end

  def want_notification(user)
    transfer_to_agent = current_ivr.nodes.where(name: "transfer_to_agent").first
    transfer_to_agent.users.include? user
  end
end
