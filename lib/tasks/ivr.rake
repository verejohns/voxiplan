namespace :ivr do
  desc "Regenerate IVR removing all existing nodes. All your changes will lost!"
  task regenerate: :environment do
    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      ivr.regenerate
    end
  end

  desc "Regenerate by copying text from default IVR"
  task copy_text_and_regenerate: :environment do

    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      ivr.copy_and_regenerate
    end
  end

  desc 'Replace sip.voxiplan.com to voxiplan.com for all existing users'
  task change_sip_domain: :environment do
    User.where('sip like ? ', '%sip.voxiplan.com').each do |u|
      u.update(sip: u.sip.gsub('sip.voxiplan.com', 'voxiplan.com'))
    end

    Identifier.where('identifier like ? ', '%sip.voxiplan.com').each do |i|
      i.update(identifier: i.identifier.gsub('sip.voxiplan.com', 'voxiplan.com'))
    end
  end

  desc "Create default missing users"
  task create_default_users: :environment do
    ids = Client.joins(:users).where('users.email = clients.email').pluck :id
    missing = Client.where.not(id: ids)
    missing.each do |client|
      client.send :create_user
    end
  end

  # TODO: remove after running on server
  desc "update default prefrences"
  task update_default_prefrences: :environment do
    Ivr.find_each{|ivr| ivr.preference['say_recorded_name'] = false; ivr.save }
  end

  desc "update text for transfer to agent node"
  task update_text_for_transfer_to_agent: :environment do
    Transfer.where(name: 'transfer_to_agent').find_each{|n| n.update_column(:text, I18n.t('static_ivr.your_call_being_transfer', locale: n.ivr.locale_from_voice)) }
  end

  desc "update ext action"
  task update_ext_action: :environment do
    ext_nodes = Node.where.not(ext_action: nil)
    ext_nodes.where(type: 'Record').update_all(ext_action: 'ext_action_send_to_voicemail')
    ext_nodes.where(type: 'Transfer').update_all(ext_action: 'ext_action_transfer_call')
    ext_nodes.where(type: 'Conditional').update_all(ext_action: 'ext_action_appointment_bot')
  end

  desc "add users to Email and Transfer nodes"
  task add_users_to_nodes: :environment do
    SendEmail.find_each do |node|
      node.update_users(node.ivr.client.users.where(email: node.to))
    end

    Transfer.find_each do |node|
      node.update_users(node.ivr.client.users.where(sip: node.to))
    end
  end

  desc "set default value to 1.day in advance"
  task set_after_time: :environment do
    AgendaApi.where(name: 'agenda_group_availabilities').each do |node|
      node.parameters['after_time'] = "%{1_day}"
      node.save
    end
  end

  task set_max_allowed_appointments_to_one: :environment do
    Ivr.find_each{|ivr| ivr.preference['max_allowed_appointments'] = 1; ivr.save }
  end

  desc "add new conditional node for allow_cancel_or_modify"
  task add_new_node_for_cancel_or_modify: :environment do
    Ivr.find_each do |ivr|

      Conditional.create(name: 'limit_not_reached', ivr: ivr,
             left_operand: "%{ivr_preference_allow_cancel_or_modify}", condition: 'eq', right_operand: true,
             next: 'cmd_menu', invalid_next: ivr.find_node('check_existing_appointments').invalid_next)

      Conditional.create(name: 'limit_reached', ivr: ivr,
             left_operand: "%{ivr_preference_allow_cancel_or_modify}", condition: 'eq', right_operand: true,
             next: 'cmd_menu', invalid_next: 'max_appointment_limit_reached')

      Say.create(name: 'max_appointment_limit_reached', ivr: ivr,
             text: t('static_ivr.appointment_max_limit_reached'),
             next: 'transfer_or_voicemail')

      ivr.find_node('check_limit').update(next: 'limit_not_reached', invalid_next: 'limit_reached')

      ivr.preference['allow_cancel_or_modify'] = true
      ivr.save
    end
  end

  desc "add new conditional node to check limit again"
  task check_limit_on_create: :environment do
    Ivr.find_each do |ivr|

      cmd_menu = ivr.find_node('cmd_menu')
      Conditional.create(name: 'check_limit_on_create', ivr: ivr,
             left_operand: "%{existing_appointment_count}", condition: 'lt', right_operand: "%{ivr_preference_max_allowed_appointments}",
             next: cmd_menu.choices['key_3'], invalid_next: 'max_appointment_limit_reached')

      cmd_menu.choices['key_3'] = 'check_limit_on_create'
      cmd_menu.save
    end
  end

  desc "fix type of appointment menu1 and menu2"
  task fix_appointment_menu_type: :environment do

    nodes = Node.where(name: %w[appointment_menu1 appointment_menu2])
    nodes.each do |node|
      I18n.locale = node.locale_from_voice.to_sym

      group_text = {
          generic: {
              single: {
                  text: I18n.t('static_ivr.appointment_group_menu.generic.single'),
                  condition: "group%{num}_slot_count == 1",
                  variables: {day: "group%{num}_day", time: "group%{num}_start", num: "%{num}"}
              },
              multiple: {
                  text: I18n.t('static_ivr.appointment_group_menu.generic.multiple'),
                  condition: "group%{num}_slot_count > 1",
                  variables: {day: "group%{num}_day", start: "group%{num}_start", finish: "group%{num}_finish", num: "%{num}"}
              }
          },
          other: I18n.t('static_ivr.appointment_group_menu.other')
      }

      node.update(text: group_text)
    end
  end


  task change_text_for_confirm_delete_and_modify: :environment do

    nodes = Node.where(name: %w[confirm_cancel confirm_modify])
    nodes.each do |node|
      I18n.locale = node.locale_from_voice.to_sym
      text = {
          explicit: {
              text: I18n.t('static_ivr.appointment_cofirmation'),
              condition: "%{ ivr_preference_implicit_confirmation == false }"
          },
          implicit: {
              text: I18n.t('static_ivr.appointment_cofirmation_implicit', time: 'choosen_existing_appointment_time'),
              condition: "%{ivr_preference_implicit_confirmation == true }"
          }
      }
      node.update(text: text)
    end
  end

  task change_back_link_for_confirm_delete_and_modify: :environment do
    nodes = Node.where(name: %w[confirm_cancel confirm_modify])
    nodes.each do |node|
      I18n.locale = node.locale_from_voice.to_sym

      new_choices = node.choices.merge(key_0: 'cmd_menu')
      node.update(choices: new_choices)
    end
  end


  task insert_hangup_sms_node: :environment do
    nodes = Node.where(name: %w[hangup_mail])
    nodes.each do |node|
      I18n.locale = node.locale_from_voice.to_sym

      SendSMS.create(ivr: node.ivr, name: 'hangup_caller_sms', to: "%{caller_id}",
             text: I18n.t('static_ivr.hangup_caller_sms'), enabled: false,
             next: 'hang')
      node.update(next: 'hangup_caller_sms')
    end
  end

  task insert_cancel_sms_node: :environment do
    nodes = Node.where(name: %w[say_cancelled])
    nodes.each do |node|
      I18n.locale = node.locale_from_voice.to_sym

      SendSMS.create(ivr: node.ivr, name: 'appointment_cancel_caller_sms', to: "%{caller_id}",
               text: I18n.t('static_ivr.appointment_cancel_caller_sms', var: 'choosen_existing_appointment_time'), enabled: true,
               next: 'hang')
      node.update(next: 'appointment_cancel_caller_sms')
    end
  end

  task update_sms_sequence: :environment do
    nodes = Node.where(name: %w[appointment_success])
    nodes.update_all(next: 'appointment_success_mail')

    nodes = Node.where(name: %w[appointment_success_recorded])
    nodes.update_all(next: 'hang')

    nodes = Node.where(name: %w[appointment_success_client_sms])
    nodes.update_all(next: 'appointment_success_record')
  end

  task update_sms_sequence_rev: :environment do

    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      AppointmentBot.new(ivr).send(:create_post_confirmation_reminder)
    end

    nodes = Node.where(name: %w[appointment_success])
    nodes.update_all(next: 'post_confirmation_reminder')

    nodes = Node.where(name: %w[appointment_success_recorded])
    nodes.update_all(next: 'appointment_success_mail')

    nodes = Node.where(name: %w[appointment_success_client_sms])
    nodes.update_all(next: 'hang')
  end

  task add_pref_to_prefer_voicemail_over_transfer: :environment do
    nodes = Node.where(name: %w[transfer_or_voicemail])
    nodes.update_all(name: 'transfer_or_voicemail_wrt_business_hours')

    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      AppointmentBot.new(ivr).send(:create_transfer_or_voicemail)
      ivr.preference['prefer_voicemail'] = false
      ivr.save
    end
  end

  task use_new_ext_for_closed_menu: :environment do
    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      transfer_extension2 = TransferExtension.new(ivr, prefix: ivr.next_extension, title: 'Extension Closed 1').build
      menu_closed = ivr.nodes.find_by(name: 'menu_closed')
      menu_closed.update(choices: menu_closed.choices.merge(key_2: transfer_extension2))
    end
  end


  task change_type_of_record_name_node: :environment do
    nodes = Node.where(name: %w[record_user_name])
    nodes.update_all(type: 'RecordName')
  end

  task disable_hangup_notify: :environment do
    nodes = Node.where(name: %w[appointment_success_recorded post_confirmation_reminder])
    nodes.update_all(notify_hangup: false)

    nodes = Node.where(name: %w[appointment_success appointment_success_record])
    nodes.update_all(next_nodes: {hangup: 'appointment_success_mail'})
  end

  task change_sequence_of_success_mail: :environment do
    nodes = Node.where(name: %w[appointment_success])
    nodes.update_all(next: 'appointment_success_record')

    nodes = Node.where(name: %w[appointment_success_record])
    nodes.update_all(next: 'appointment_success_mail')

    nodes = Node.where(name: %w[appointment_success_client_sms])
    nodes.update_all(next: 'appointment_success_recorded')

    nodes = Node.where(name: %w[appointment_success_recorded])
    nodes.update_all(next: 'post_confirmation_reminder')

    nodes = Node.where(name: %w[post_confirmation_reminder])
    nodes.update_all(next: 'hang')
  end


  task disable_for_test: :environment do
    # nodes = Node.where(name: %w[check_existing_caller])
    # nodes.update_all(enabled: true)
    nodes = Node.where(name: %w[welcome_closed welcome_open announcement_closed announcement_open check_caller_id gather_number save_number appointment_announcement appointment_announcement_closed])
    nodes.update_all(enabled: false)
  end

  task update_modify_appointment: :environment do
    nodes = Node.where(name: %w[get_existing_appointments])
    nodes.update_all(results: {id: 'existing_appointment_id', time: 'existing_appointment_time', resource: 'existing_appointment_resource', service: 'existing_appointment_service'})

    nodes = Node.where(name: %w[choosen_modify_appointment])
    nodes.update_all(parameters: {prefix: 'existing_appointment', selected: "%{modify_menu}", save_as: 'choosen_existing_appointment', keys: %w[id time resource service] })

    nodes = Node.where(name: %w[choosen_cancel_appointment])
    nodes.update_all(parameters: {prefix: 'existing_appointment', selected: "%{cancel_menu}", save_as: 'choosen_existing_appointment', keys: %w[id time resource service] })

    nodes = Node.where(name: %w[modify_appointment])
    nodes.update_all(type: 'AliasVariable', parameters: [{original: 'choosen_existing_appointment_service', alias: 'choosen_service'}, {original: 'choosen_existing_appointment_resource', alias: 'choosen_resource'}], next: 'agenda_group_availabilities' )
  end

  task create_default_resource_and_service: :environment do
    Ivr.find_each do |ivr|
      ivr.send(:set_default_resource_and_service)
    end
  end

  desc "update default prefrences set sms_from"
  task update_default_prefrences_set_sms_from: :environment do
    Ivr.find_each{|ivr| ivr.preference['sms_from'] = '' and ivr.save if ivr.preference['sms_from'].blank?}
  end

  desc "remove_modify_confirmation"
  task remove_modify_confirmation: :environment do
    nodes = Node.where(name: %w[if_can_modify])
    nodes.update_all(next: 'modify_appointment')

    Node.where(name: %w[confirm_modify]).delete_all
  end
  # moved to migrations.rake
  task create_ai_nodes: :environment do
    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      AppointmentBot.new(ivr).send(:create_ai_nodes)
    end
  end

  desc "update update_prefrences_bot_offer_strategy"
  task update_prefrences_bot_offer_strategy: :environment do
    Ivr.find_each{|ivr| ivr.preference['bot_offer_strategy'] = 'first_available_slot'; ivr.save }
  end

  task check_caller_it_at_start: :environment do
    # change start of bot
    nodes = Node.where(name: %w[menu_open menu_closed])
    nodes.each do |node|
      node.next = 'check_existing_caller'
      key = node.choices.select{|k,v| v == 'check_caller_id'}.keys.first
      node.choices[key] = 'check_existing_caller' if key
      node.save
    end

    nodes = Node.where(name: %w[check_caller_id])
    # confirm on dev
    nodes.update_all(invalid_next: 'announcement_wrt_business_hours')

    nodes = Node.where(name: %w[save_number])
    nodes.update_all(next: 'announcement_wrt_business_hours')

    nodes = Node.where(name: %w[welcome_open welcome_closed])
    nodes.update_all(next: 'check_caller_id')

    Ivr.find_each do |ivr|
      Conditional.create(name: 'announcement_wrt_business_hours', ivr: ivr,
                         left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
                         next: 'announcement_open', invalid_next: 'announcement_closed')
    end
  end

  desc "Delete duplicate call records"
  task delete_duplicate_calls: :environment do
    calls = Call.where.not(tropo_call_id: nil)
    cg = calls.group_by{|c| c['tropo_call_id']}
    cg2 = cg.select{|k,v| v.size > 1}
    cg3 = cg2.select{|_,v| v.map{|o| a= o.dup; a.created_at = a.updated_at = nil; a.attributes }.uniq.size == 1 }
    ids = cg3.map{|_,v| v[1..-1]}.flatten.map(&:id)
    Call.where(id: ids).destroy_all
  end

end
