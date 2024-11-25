class AppointmentBot < IvrBuilder
  START = 'check_existing_caller'

  def ext_action
    'ext_action_appointment_bot'
  end

  def create_variable(name:, variable_name: nil , value: 1, next_node:)
    create(Variable, name,
           left_operand: variable_name,
           right_operand: value,
           next: next_node)
  end

  def increment_tries(start_node:, next_node:, variable_name: ,  max_tries: 6)

    create(Arithmetic, start_node,
           left_operand: "%{#{variable_name}}", condition: '+', right_operand: 1,
           next: 'check_max_tries')

    create(Conditional, 'check_max_tries',
           left_operand: "%{#{variable_name}}", condition: 'lt', right_operand: max_tries,
           next: next_node, invalid_next: "reset_#{variable_name}")

    create(Variable, "reset_#{variable_name}",
           left_operand: "%{#{variable_name}}", right_operand: 0,
           next: 'allow_exit')

    create(Conditional, 'allow_exit',
           left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
           next: 'transfer_menu_open', invalid_next: 'transfer_menu_closed')

    create(Menu, 'transfer_menu_open',
           text: t('static_ivr.transfer_menu_open'),
           timeout: 5,
           timeout_next: next_node, invalid_next: 'transfer_menu_open',
           choices: {key_0: 'transfer_or_voicemail'})

    create(Menu, 'transfer_menu_closed',
           text: t('static_ivr.transfer_menu_closed'),
           timeout: 5,
           timeout_next: next_node, invalid_next: 'transfer_menu_closed',
           choices: {key_0: 'transfer_or_voicemail'})

  end

  def gather_number_context
    [
      {input: "19298090#"},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end

  def appointment_announcement_context
    [
      {msg: t('static_ivr.gather_number'), input: "19298090#"},
      {msg: t('context.select_resource'), input: 1},
      {msg: t('context.select_time'), input: 1},
      {msg: t('context.appointment_confirmed'), input: nil}
    ]
  end

  # Move to static_ivr.rb
  # setting name to caller_id instead of check_caller_id so that we know where is breaks
  def check_caller_id(name: 'check_caller_id', next_node: 'business_hours')
    create(Conditional, name,
             {
               left_operand: "%{caller_id}", condition: 'in', right_operand: TwilioEngine::EXCEPTION_NUMBERS,
               next: 'gather_number', invalid_next: 'announcement_wrt_business_hours'
             }
           )

    create(GatherPhoneNumber, 'gather_number', text: t('static_ivr.gather_number'),
           input_min_length: 7, input_max_length: 15,
           next: 'save_number', invalid_next: 'say_invalid_number', context: gather_number_context)

    create(Say, 'say_invalid_number', text: t('static_ivr.say_invalid_number'),
           next: 'gather_number')

    create(AliasVariable, 'save_number',
           parameters: [{original: 'gather_number', alias: 'caller_id'}],
           next: 'announcement_wrt_business_hours')

    check_existing_caller(name: 'check_existing_caller', next_node: 'appointment_announcement')
  end

  def appointment_announcement(name: 'appointment_announcement', next_node:)
    create(Conditional, name,
           left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
           next: 'appointment_announcement_open', invalid_next: 'appointment_announcement_closed')

    create(Say, 'appointment_announcement_open', text: t('static_ivr.appointment_announcement_open'),
           next: next_node, context: appointment_announcement_context)

    create(Say, 'appointment_announcement_closed', text: t('static_ivr.appointment_announcement_closed'),
           next: next_node, context: appointment_announcement_context)
  end

  # TODO: Remove this method - old code
  # def caller_id_and_announcement(name: AppointmentBot::START, next_node:)
  #   create(Conditional, name,
  #          ext_options.merge(
  #            {
  #              left_operand: "%{caller_id}", condition: 'in', right_operand: ['737 874-2833', '7378742833', '+7378742833' ,
  #                                                                             '256-2533','2562533', '+2562533',
  #                                                                             '865-6696', '8656696', '+8656696',
  #                                                                             '266696687', '+266696687',
  #                                                                             '86282452253', '+86282452253', nil],
  #              next: 'gather_number', invalid_next: 'check_existing_caller'
  #            }
  #          ))
  #
  #   create(GatherPhoneNumber, 'gather_number', text: t('static_ivr.gather_number'),
  #          input_min_length: 7, input_max_length: 15,
  #          next: 'save_number', invalid_next: 'say_invalid_number', context: gather_number_context)
  #
  #   create(Say, 'say_invalid_number', text: t('static_ivr.say_invalid_number'),
  #          next: 'gather_number')
  #
  #   create(AliasVariable, 'save_number',
  #          parameters: [{original: 'gather_number', alias: 'caller_id'}],
  #          next: 'check_existing_caller')
  #
  #   check_existing_caller(name: 'check_existing_caller', next_node: 'appointment_announcement')
  #
  #   create(Conditional, 'appointment_announcement',
  #          left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
  #          next: 'appointment_announcement_open', invalid_next: 'appointment_announcement_closed')
  #
  #   create(Say, 'appointment_announcement_open', text: t('static_ivr.appointment_announcement_open'),
  #          next: next_node, context: appointment_announcement_context)
  #
  #   create(Say, 'appointment_announcement_closed', text: t('static_ivr.appointment_announcement_closed'),
  #          next: next_node, context: appointment_announcement_context)
  # end

  def check_existing_caller(name:, next_node:)
    create(AgendaApi, name, ext_options.merge(
           method_name: 'existing_caller',
           next_nodes: {disabled: next_node},
           next: next_node,
           invalid_next: 'client_allows_new_customers', # not existing caller
    ))

    create(Conditional, 'client_allows_new_customers',
           left_operand: "%{ivr_preference_allow_new_customers}", condition: 'eq', right_operand: true,
           next: 'record_user_name',
           invalid_next: 'new_customers_not_allowed'
    )

    create(Say,'new_customers_not_allowed',
           text: t('static_ivr.new_customer_not_allowed'),
           next: 'transfer_or_voicemail')

    create(RecordName, 'record_user_name',
           text: t('static_ivr.new_customer_enter_your_name'),
           parameters: {file_name: 'user_name_record'},
           next: 'create_new_caller')

    create(AgendaApi, 'create_new_caller',
           method_name: 'create_new_caller',
           next_nodes: {disabled: next_node},
           parameters: {recorded_user_name: "%{record_user_name}"},
           next: next_node,
           invalid_next: 'transfer_or_voicemail', # TODO if there is an error while create user.
    )

  end

  def create_ai_nodes
    if @ivr.assistant_name == "Laura"
      right_operand = "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{@ivr.message_locale[0..1]}'}"
    else
      right_operand = "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{@ivr.message_locale[0..1]}', 'assistant_name': '#{@ivr.assistant_name}'}"
    end

    create(Variable, 'ai_bot_start_conversation',
           left_operand: 'user_says', right_operand: right_operand,
           next: 'ai_bot_dialogue')

    create(BotDialogue, 'ai_bot_dialogue', next: 'ai_bot_gather',
           next_nodes: {
             ai_bot_finish: 'ai_bot_finish'
           })

    create(BotGather, 'ai_bot_gather', next: 'ai_bot_dialogue',
           next_nodes: {
             ai_bot_finish: 'ai_bot_finish'
           })

    create(Say, 'ai_bot_finish', text: "%{bot_says}", next: 'hang')
  end

  def resource_and_services(next_node:)
    if options[:service_first]
      next_node_name = create_resource(next_node: next_node)
      create_service(next_node: next_node_name)
    else
      next_node_name = create_service(next_node: next_node)
      create_resource(next_node: next_node_name)
    end
  end

  def create_resource(name: 'agenda_resources', next_node:)
    return next_node unless options[:enable_resource]

    create(AgendaApi, name,
           method_name: 'resources',
           parameters: {service: "%{choosen_service}"},
           results: {id: 'resource_id', name: 'resource_name'},
           next_nodes: {disabled: next_node},
           next: 'check_resource_availability'
    )

    create(Conditional, 'check_resource_availability',
           left_operand: "%{resource_count}", condition: 'eq', right_operand: 0,
           next: next_node, invalid_next: 'check_if_one_resource')

    create(Conditional, 'check_if_one_resource',
           left_operand: "%{resource_count}", condition: 'eq', right_operand: 1,
           next: 'set_choose_resource', invalid_next: 'select_resource')

    create(AliasVariable, 'set_choose_resource',
           parameters: [{original: 'resource_id1', alias: 'choosen_resource'}],
           next: next_node)


    select_resource = {
      generic: I18n.t('static_ivr.resources.generic', var: 'resource_name', num: 'num'),
      other: I18n.t('static_ivr.resources.other')
    }
    select_resource_opts = {
      text: select_resource,
      timeout: 5, tries: 2,
      timeout_next: 'timeout', invalid_next: 'invalid',
      parameters: { 'selected_next' => 'choosen_resource', 'variable_name' =>  'resource_name'},
      choices: {key_9: 'select_resource'}
    }
    create(Menu, 'select_resource', select_resource_opts)

    create(AgendaApi, 'choosen_resource',
           method_name: 'choose_selected',
           parameters: {prefix: 'resource_id', selected: "%{select_resource}", save_as: 'choosen_resource'},
           next: next_node
    )
    name
  end

  def create_service(name: 'agenda_services', next_node:)
    return next_node unless options[:enable_service]

    create(AgendaApi, name,
           method_name: 'services',
           parameters: {resource: "%{choosen_resource}"},
           results: {id: 'service_id', name: 'service_name'},
           next_nodes: {disabled: next_node},
           next: 'check_service_availability'
    )

    create(Conditional, 'check_service_availability',
           left_operand: "%{service_count}", condition: 'eq', right_operand: 0,
           next: next_node, invalid_next: 'check_if_one_service')

    create(Conditional, 'check_if_one_service',
           left_operand: "%{service_count}", condition: 'eq', right_operand: 1,
           next: 'set_choosen_service', invalid_next: 'select_service')

    create(AliasVariable, 'set_choosen_service',
           parameters: [{original: 'service_id1', alias: 'choosen_service'}],
           next: next_node)

    select_service = {
      generic: I18n.t('static_ivr.services.generic', var: 'service_name', num: 'num'),
      other: I18n.t('static_ivr.services.other')
    }
    select_service_opts = {
      text: select_service,
      timeout: 5, tries: 2,
      timeout_next: 'timeout', invalid_next: 'invalid',
      parameters: { 'selected_next' => 'choosen_service', 'variable_name' => 'service_name'},
      choices: {key_9: 'select_service'}
    }
    create(Menu, 'select_service', select_service_opts)

    create(AgendaApi, 'choosen_service',
           method_name: 'choose_selected',
           parameters: {prefix: 'service_id', selected: "%{select_service}", save_as: 'choosen_service'},
           next: next_node
    )

    name
  end


  def confirm(slot_num,text=nil)
    create(AliasVariable,"confirm#{slot_num}",
           parameters: [
             {original: "slot#{slot_num}_start", alias: 'choosen_slot_start'},
             {original: "slot#{slot_num}_sid", alias: 'choosen_slot_sid'}],
           next: 'set_back_when_multiple_group_slots',
           text: text)
  end

  def confirm_single_group(num)
    create(AliasVariable, "confirm_single_group#{num}",
           parameters: [
               {original: "group#{num}_single_start", alias: 'choosen_slot_start'},
               {original: "group#{num}_single_sid", alias: 'choosen_slot_sid'}],
           next: "set_back_when_single_slot_group#{num}")

    create_variable(name: "set_back_when_single_slot_group#{num}", variable_name: 'back_to' , value: "appointment_menu#{num}", next_node: 'confirm_create')
  end

  def confirm_single_group_slot(group_num,text=nil)
    create(AliasVariable,"confirm_single_group_slot#{group_num}",
           parameters: [
               {original: "group#{group_num}_slot_start", alias: 'choosen_slot_start'},
               {original: "group#{group_num}_slot_sid", alias: 'choosen_slot_sid'}],
           next: 'confirm_create')
  end

  def create_post_confirmation_reminder
    create(Say,'post_confirmation_reminder',
           text: t('static_ivr.post_confirmation_reminder'),
           enabled: false, notify_hangup: false,
           next: 'tracking_url')
  end

  def make_appointment
    create(AgendaApi, 'make_appointment',
           method_name: 'make_appointment',
           parameters: {sid: "%{choosen_slot_sid}"},
           next: 'appointment_success', invalid_next: 'appointment_fail')

    create(Menu, 'confirm_create',
           text: confirmation_node_text,
           timeout: 5,tries: 2, enabled: false,
           timeout_next: 'timeout', invalid_next: 'invalid',
           next: 'make_appointment',
           parameters: {text_concat_method: 'conditions'},
           choices: {key_1: 'make_appointment', key_0: '%{back_to}'})

    create(Say,'appointment_success',
           text: t('static_ivr.appointment_success', time: 'choosen_slot_start', name: 'customer_first_name'),
           next_nodes: {hangup: 'appointment_success_mail'},
           notify_hangup: false,
           next: 'appointment_success_record')


    create(Say,'appointment_fail',
           text: t('static_ivr.appointment_fail'),
           next: 'transfer_or_voicemail')

    create(Record, 'appointment_success_record',
           text: t('static_ivr.appointment_success_record'),
           parameters: {file_name: 'appointment_success_record'},
           next_nodes: {hangup: 'appointment_success_mail'},
           notify_hangup: false, enabled: false,
           next: 'appointment_success_mail')

    create_post_confirmation_reminder

    create(TrackingURL, 'tracking_url', next: 'hang', enabled: false, can_enable: true)

    create(Say,'appointment_success_recorded',
           text: t('static_ivr.appointment_success_recorded'),
           notify_hangup: false, enabled: false,
           next: 'post_confirmation_reminder')

    create(SendEmail, 'appointment_success_mail', users: default_users,
           text: {
               title: I18n.t("mails.client_appointment_confirmed.title"),
               greetings: I18n.t("mails.client_appointment_confirmed.greetings"),
               summary: I18n.t("mails.client_appointment_confirmed.summary"),
               booking_details: I18n.t("mails.client_appointment_confirmed.booking_details"),
               caller: I18n.t("mails.client_appointment_confirmed.caller"),
               date: I18n.t("mails.client_appointment_confirmed.date"),
               play_recording_btn_text: I18n.t("mails.client_appointment_confirmed.play_recording_btn_text"),
               play_recording_btn_url: I18n.t("mails.client_appointment_confirmed.play_recording_btn_url"),
               conclusion: I18n.t("mails.client_appointment_confirmed.conclusion"),
               copyright: I18n.t("mails.copyright"),
               reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us"),
           },
           email_subject: t('static_ivr.appointment_success_mail_sub'),
           parameters: {
               template_id: 'd-78cbb441410e49b4b5dd9bdedc3b639f',
           },
           next: 'appointment_success_caller_sms')

    create(SendSMS, 'appointment_success_caller_sms', to: "%{caller_id}",
           text: t('static_ivr.appointment_success_caller_sms', time: 'choosen_slot_start'), enabled: true,
           parameters: {appointment_time: "%{choosen_slot_start}"},
           next: 'appointment_success_client_sms')

    create(SendSMS, 'appointment_success_client_sms', users: default_users,
           text: t('static_ivr.appointment_success_client_sms', time: 'choosen_slot_start', caller: 'caller_id'), enabled: true,
           parameters: {appointment_time: "%{choosen_slot_start}"},
           next: 'appointment_success_recorded')
  end

  def create_transfer_or_voicemail
    create(Conditional, 'transfer_or_voicemail',
           left_operand: "%{ivr_preference_prefer_voicemail}", condition: 'eq', right_operand: true,
           next: 'voice_to_email_record', invalid_next: 'transfer_or_voicemail_wrt_business_hours')
  end

  # transfer_or_voicemail
  # if within business hours and ivr_preference_prefer_voicemail is false then transfer otherwise record msg
  # used on many places like given below
  # max_appointment_limit_reached
  # say_cancel_time_limit_reached
  # timeout
  # invalid (user enters wrong input)
  # internal_error
  # speak to someone (press 0)
  # could not find any availability
  def transfer_or_voicemail
    create_transfer_or_voicemail
    create(Conditional, 'transfer_or_voicemail_wrt_business_hours',
           left_operand: "%{business_hours}", condition: 'eq', right_operand: true,
           next: 'transfer_to_agent', invalid_next: 'voice_to_email_record')

    create(Transfer, 'transfer_to_agent',
           text: I18n.t('static_ivr.your_call_being_transfer'),
           users: default_users, from: "%{caller_id}")
  end

  def self.build(ivr, options = {})
    options[:scheduling_method] ||= 'by_preference'
    options[:service_first] ||= true
    options[:enable_service] ||= true
    options[:enable_resource] ||= true
    options[:manual] ||= false

    if options[:ai_bot]
      AiBot.new(ivr, options).build
    elsif options[:scheduling_method] == 'by_preference'
      FifoConstraints.new(ivr, options).build
    else
      Fifo.new(ivr, options).build
    end
  end

  def build
    # see child classes
    raise 'Not implemented in child class'
  end

end