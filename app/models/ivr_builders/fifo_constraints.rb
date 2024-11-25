class FifoConstraints < AppointmentBot

  def build
    res_ser_next = resource_and_services(next_node: 'agenda_group_availabilities')
    # caller_id_and_announcement(next_node: 'get_existing_appointments')
    check_caller_id
    appointment_announcement(next_node: 'get_existing_appointments')
    manage_existing_appointments(next_node: res_ser_next)
    group_availabilities(name: 'agenda_group_availabilities', next_node: 'slot_availabilities')
    menu3
    menu4
    confirm(1)
    confirm(2)
    confirm(3, t('static_ivr.new_customer_enter_your_name'))
    handle_no_slot_found
    make_appointment
    transfer_or_voicemail
    create_ai_nodes
    START
  end

  # create modify or delete
  def manage_existing_appointments(next_node: )

    create(AgendaApi, 'get_existing_appointments',
           method_name: 'existing_appointments',
           results: {id: 'existing_appointment_id', time: 'existing_appointment_time', resource: 'existing_appointment_resource', service: 'existing_appointment_service'},
           next: 'check_existing_appointments'
    )

    create(Conditional, 'check_existing_appointments',
           left_operand: "%{existing_appointment_count}", condition: 'gt', right_operand: 0,
           next: 'check_if_only_one_appointment', invalid_next: next_node)

    create(Conditional, 'check_if_only_one_appointment',
           left_operand: "%{existing_appointment_count}", condition: 'eq', right_operand: 1,
           next: 'check_limit', invalid_next: 'check_if_more_then_one_appointment')

    create(Conditional, 'check_if_more_then_one_appointment',
           left_operand: "%{existing_appointment_count}", condition: 'gt', right_operand: 1,
           next: 'check_limit', invalid_next: 'check_limit')

    create(Conditional, 'check_limit',
           left_operand: "%{existing_appointment_count}", condition: 'lt', right_operand: "%{ivr_preference_max_allowed_appointments}",
           next: 'limit_not_reached', invalid_next: 'limit_reached')

    create(Conditional, 'limit_not_reached',
           left_operand: "%{ivr_preference_allow_cancel_or_modify}", condition: 'eq', right_operand: true,
           next: 'cmd_menu', invalid_next: next_node)

    create(Conditional, 'limit_reached',
           left_operand: "%{ivr_preference_allow_cancel_or_modify}", condition: 'eq', right_operand: true,
           next: 'cmd_menu', invalid_next: 'max_appointment_limit_reached')

    create(Say,'max_appointment_limit_reached',
           text: t('static_ivr.appointment_max_limit_reached'),
           next: 'transfer_or_voicemail')

    menu_opts = {
      text: {
        #   todo say time
        only_one_appointment: {
            text: t('static_ivr.cmd_menu.only_one_appointment', time: 'existing_appointment_time1'),
            condition: "%{check_if_only_one_appointment}"
        },
        more_then_one_appointments: {
            text: t('static_ivr.cmd_menu.more_then_one_appointments', count: 'existing_appointment_count'),
            condition: "%{check_if_more_then_one_appointment}"
        },
        modify: { text: t('static_ivr.cmd_menu.modify'), condition: "%{check_existing_appointments}"},
        delete: { text: t('static_ivr.cmd_menu.delete'), condition: "%{check_existing_appointments}"},
        create: { text: t('static_ivr.cmd_menu.create'), condition: "%{check_limit}"},
        other:  { text: t('static_ivr.to_repeat_and_other')}
      },
      timeout: 5,
      timeout_next: 'cmd_menu', invalid_next: 'cmd_menu',
      parameters: {text_concat_method: 'conditions'},
      choices: {key_1: 'modify_action', key_2: 'cancel_action', key_3: 'check_limit_on_create'}
    }
    create(Menu, 'cmd_menu', menu_opts)

    modify_and_cancel_appointment(next_node: next_node)

    create(Conditional, 'check_limit_on_create',
           left_operand: "%{existing_appointment_count}", condition: 'lt', right_operand: "%{ivr_preference_max_allowed_appointments}",
           next: next_node, invalid_next: 'max_appointment_limit_reached')
  end

  def modify_and_cancel_appointment(next_node: )
    create(Conditional, 'modify_action',
           left_operand: "%{check_if_only_one_appointment}", condition: 'eq', right_operand: true,
           next: 'select_only_appointment_for_modify', invalid_next: 'modify_menu')

    create(Variable, 'select_only_appointment_for_modify',
           left_operand: 'modify_menu', right_operand: 1,
           next: 'choosen_modify_appointment')

    # modify menu
    menu_text = {
      generic: I18n.t('static_ivr.modify_appointment.generic', var: 'existing_appointment_time', num: 'num'),
      other: I18n.t('static_ivr.resources.other')
    }
    menu_opts = {
      text: menu_text,
      timeout: 5, tries: 2,
      timeout_next: 'timeout', invalid_next: 'invalid',
      parameters: { 'selected_next' => 'choosen_modify_appointment',
                    'variable_name' =>  'existing_appointment_time',
                    'count_variable' => 'existing_appointment_count'},
      choices: {key_9: 'modify_menu'}
    }
    create(Menu, 'modify_menu', menu_opts)

    create(AgendaApi, 'choosen_modify_appointment',
           method_name: 'choose_selected',
           parameters: {prefix: 'existing_appointment', selected: "%{modify_menu}", save_as: 'choosen_existing_appointment', keys: %w[id time resource service] },
           next: 'can_modify_existing_appt'
    )

    create(AgendaApi, 'can_modify_existing_appt',
           method_name: 'can_cancel_or_modify',
           parameters: {choosen_existing_appointment: 'choosen_existing_appointment_time'},
           next: 'if_can_modify'
    )

    create(Conditional, 'if_can_modify',
           left_operand: "%{can_modify_existing_appt}", condition: 'eq', right_operand: true,
           next: 'modify_appointment', invalid_next: 'say_cancel_time_limit_reached')

    create(AliasVariable,'modify_appointment',
           parameters: [{original: 'choosen_existing_appointment_service', alias: 'choosen_service'}, {original: 'choosen_existing_appointment_resource', alias: 'choosen_resource'}],
           next: 'agenda_group_availabilities' )

    create(Conditional, 'cancel_action',
           left_operand: "%{check_if_only_one_appointment}", condition: 'eq', right_operand: true,
           next: 'select_only_appointment_for_cancel', invalid_next: 'cancel_menu')

    create(Variable, 'select_only_appointment_for_cancel',
           left_operand: 'cancel_menu', right_operand: 1,
           next: 'choosen_cancel_appointment')

    # create(Menu, 'confirm_modify',
    #        text: confirmation_node_text('choosen_existing_appointment_time'),
    #        timeout: 5,tries: 2, enabled: false,
    #        timeout_next: 'timeout', invalid_next: 'invalid',
    #        next: 'modify_appointment',
    #        parameters: {text_concat_method: 'conditions'},
    #        choices: {key_1: 'modify_appointment', key_0: 'cmd_menu'})

    # Remove?
    create(Say,'say_modified',
           text: t('static_ivr.appointment_modified'),
           next: next_node)

    # cancel menu
    menu_text = {
      generic: I18n.t('static_ivr.cancel_appointment.generic', var: 'existing_appointment_time', num: 'num'),
      other: I18n.t('static_ivr.resources.other')
    }

    menu_opts = {
      text: menu_text,
      timeout: 5, tries: 2,
      timeout_next: 'timeout', invalid_next: 'invalid',
      parameters: { 'selected_next' => 'choosen_cancel_appointment',
                    'variable_name' =>  'existing_appointment_time',
                    'count_variable' => 'existing_appointment_count'},
      choices: {key_9: 'cancel_menu'}
    }

    create(Menu, 'cancel_menu', menu_opts.merge(text: menu_text))

    create(AgendaApi, 'choosen_cancel_appointment',
           method_name: 'choose_selected',
           parameters: {prefix: 'existing_appointment', selected: "%{cancel_menu}", save_as: 'choosen_existing_appointment', keys: %w[id time resource service] }, # here add
           next: 'can_cancel_existing_appt'
    )

    create(AgendaApi, 'can_cancel_existing_appt',
           method_name: 'can_cancel_or_modify',
           parameters: {choosen_existing_appointment: 'choosen_existing_appointment_time'},
           next: 'if_can_cancel'
    )

    create(Conditional, 'if_can_cancel',
           left_operand: "%{can_cancel_existing_appt}", condition: 'eq', right_operand: true,
           next: 'confirm_cancel', invalid_next: 'say_cancel_time_limit_reached')

    cancel_appointment(node_name: 'cancel_existing_appointment', next_node: 'say_cancelled')

    create(Menu, 'confirm_cancel',
           text: confirmation_node_text('choosen_existing_appointment_time'),
           timeout: 5,tries: 2, enabled: false,
           timeout_next: 'timeout', invalid_next: 'invalid',
           next: 'cancel_existing_appointment',
           parameters: {text_concat_method: 'conditions'},
           choices: {key_1: 'cancel_existing_appointment', key_0: 'cmd_menu'})

    # say cancel and hang
    create(Say,'say_cancelled',
           text: t('static_ivr.appointment_cancelled'),
           notify_hangup: false,
           next: 'hang')

    create(SendSMS, 'appointment_cancel_caller_sms', to: "%{caller_id}",
           text: t('static_ivr.appointment_cancel_caller_sms', var: 'choosen_existing_appointment_time'), enabled: true,
           next: 'hang')

    create(Say,'say_cancel_time_limit_reached',
           text: t('static_ivr.cancel_time_limit_reached'),
           notify_hangup: false,
           next: 'transfer_or_voicemail')
  end

  def cancel_appointment(next_node: , node_name:)
    create(AgendaApi, node_name,
           method_name: 'cancel_appointment',
           parameters: {existing_appointment: 'choosen_existing_appointment'},
           next: next_node
    )
  end

  def menu3
    create(AliasVariable,'slot_availabilities',
           parameters: [{original: 'choosen_group', alias: 'slot3_start'}],
           next: 'configure_full_day' )

    constraints = {full_day: "%{full_day}", weekday: "%{search_by_weekday}",
                   ampm: "%{search_by_ampm}", time_slot: "%{search_by_time}",
                   service_id: "%{choosen_service}", resource_id: "%{choosen_resource}"}

    create(Conditional, 'configure_full_day',
           left_operand: "%{search_by_ampm}", condition: 'or', right_operand: "%{search_by_time}",
           next: 'unset_full_day', invalid_next: 'set_full_day')

    create_variable(name: 'set_full_day' , variable_name: 'full_day', value: true, next_node: 'configure_time_format')
    create_variable(name: 'unset_full_day' , variable_name: 'full_day', value: false, next_node: 'configure_time_format')

    create(Conditional, 'configure_time_format',
           left_operand: "%{search_by_ampm}", condition: 'or', right_operand: "%{search_by_time}",
           next: 'set_custom_time_format', invalid_next: 'set_hour_time_format')

    create_variable(name: 'set_hour_time_format' , variable_name: 'time_format', value: 'hour', next_node: 'agenda_slot_availabilities')
    create_variable(name: 'set_custom_time_format' , variable_name: 'time_format', value: 'custom', next_node: 'agenda_slot_availabilities')

    create(AgendaApi, 'agenda_slot_availabilities',
           method_name: 'free_slots',
           parameters: {number_of_slots: 3, after_time: "%{slot3_start}", options: constraints},
           results: [{start: 'slot1_start', sid: 'slot1_sid' },
                     {start: 'slot2_start', sid: 'slot2_sid' },
                     {start: 'slot3_start', sid: 'slot3_sid' }],
           next: 'appointment_menu3', invalid_next: 'no_more_free_slots')

    appointment_menu3_text = {
      key1: t('static_ivr.appointment_group_menu3.time1', time1: 'slot1_start'),
      key2: t('static_ivr.appointment_group_menu3.time2', time2: 'slot2_start'),
      key3: t('static_ivr.appointment_group_menu3.time3', time3: 'slot3_start'),
      other: t('static_ivr.appointment_group_menu3.other')
    }
    appointment_menu3_opts = {
      text: appointment_menu3_text,
      timeout: 5, tries: 1,
      timeout_next: 'check_slot_count', invalid_next: 'appointment_menu3',
      parameters: {'time_format': "%{time_format}"},
      choices: {key_1: 'confirm1', key_2: 'confirm2', key_3: 'confirm3', key_9: 'appointment_menu3'}
    }

    create_variable(name: 'set_back_when_multiple_group_slots', variable_name: 'back_to' , value: "appointment_menu3", next_node: 'confirm_create')


    appointment_menu3_opts.deep_merge!(
      text: appointment_menu3_text.merge(other: t('static_ivr.appointment_group_menu3.manual_other')),
      tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
      choices: {key_4: 'check_slot_count'}
    ) if @options[:manual]

    create(Menu, 'appointment_menu3', appointment_menu3_opts)

    create(Conditional, 'check_slot_count',
           left_operand: "%{slot_count}", condition: 'lt', right_operand: 3,
           next: 'no_more_free_slots', invalid_next: 'agenda_slot_availabilities')
  end

  def menu4
    menu4_opts = {
      text: t('static_ivr.appointment_group_menu4'),
      timeout: 5,
      timeout_next: 'appointment_menu4', invalid_next: 'appointment_menu4',
      choices: {key_1: 'search_by_date', key_2: 'search_by_weekday', key_3: 'search_by_ampm', key_4: 'search_by_time', key_0: 'transfer_or_voicemail'}
    }
    create(Menu, 'appointment_menu4', menu4_opts)
    search_by_constraints
  end


  def search_by_constraints(next_node: 'slot_availabilities')
    create(GatherNumber, 'search_by_date', text: t('static_ivr.search_by_date'),
           input_min_length: 8, input_max_length: 8,
           next: 'search_by_date_alias')
    create(AliasVariable,'search_by_date_alias',
           parameters: [{original: 'search_by_date', alias: 'slot3_start'}],
           next: next_node )

    create(GatherNumber, 'search_by_weekday', text: t('static_ivr.search_by_weekday'),
           input_min_length: 1, input_max_length: 1,
           next: 'check_start_time')

    create(Conditional, 'check_start_time',
           left_operand: "%{slot3_start}", condition: 'eq', right_operand: "%{nil}",
           next: 'set_current_time_as_start', invalid_next: next_node
    )
    create(AliasVariable,'set_current_time_as_start',
           parameters: [{original: 'current_time', alias: 'slot3_start'}],
           next: next_node )

    create(Menu, 'search_by_ampm', text: t('static_ivr.search_by_ampm'),
           input_min_length: 1, input_max_length: 1,
           timeout_next: 'search_by_ampm', invalid_next: 'search_by_ampm',
           choices: {key_1: 'set_am', key_2: 'set_pm'})

    create_variable(name: 'set_am', variable_name: 'search_by_ampm', value: 'am', next_node: next_node)
    create_variable(name: 'set_pm', variable_name: 'search_by_ampm', value: 'pm', next_node: next_node)

    create(GatherNumber, 'search_by_time', text: t('static_ivr.search_by_time'),
           input_min_length: 4, input_max_length: 4,
           next: 'check_start_time')
  end


  def handle_no_slot_found
    create(Conditional, 'no_more_free_slots',
           left_operand: "%{search_by_date}", condition: 'eq', right_operand: "%{nil}",
           next: 'no_slot_found_for_menu2', invalid_next: 'no_slot_found_for_menu4')

    create(Menu, 'no_slot_found_for_menu2',
           text: t('static_ivr.appointment_group_menu2_no_slot_found'),
           timeout: 5, tries: 2,
           timeout_next: 'timeout', invalid_next: 'invalid',
           choices: {key_1: 'slot_availabilities', key_2: 'ask_for_next_group'})

    create(Conditional, 'ask_for_next_group',
           left_operand: "%{choosen_group}", condition: 'gt', right_operand: "%{group1_date}",
           next: 'agenda_other_group_availabilities', invalid_next: 'other_group_availabilities')

    create(Menu, 'no_slot_found_for_menu4',
           text: t('static_ivr.appointment_group_menu4_no_slot_found'),
           timeout: 5, tries: 2,
           timeout_next: 'timeout', invalid_next: 'invalid',
           choices: {key_1: 'search_by_date_alias', key_2: 'search_by_date', key_3: 'reset_and_choose_other_preference'})

    create(Variable, 'reset_and_choose_other_preference', next: 'appointment_menu4',
           left_operand: 'search_by_date', right_operand: "%{nil}")
  end

  def group_availabilities(name: 'agenda_group_availabilities', next_node: )
    group1 = {day: 'group1_day', start: 'group1_start', finish: 'group1_finish', date: 'group1_date', next_date: 'group1_next', slot_count: 'group1_slot_count'}
    group2 = {day: 'group2_day', start: 'group2_start', finish: 'group2_finish', date: 'group2_date', next_date: 'group2_next', slot_count: 'group2_slot_count'}

    create(AgendaApi, name,
           method_name: 'slot_groups',
           parameters: {number_of_groups: 1, after_time: "%{1_day}",
                        options: {service_id: "%{choosen_service}", resource_id: "%{choosen_resource}"},
                        slot_results: [{start: 'group1_single_start', sid: 'group1_single_sid' }]
           },
           results: [group1],
           next: 'appointment_menu1')

    group_text = {
        generic: {
            single: {
                text: t('static_ivr.appointment_group_menu.generic.single'),
                condition: "group%{num}_slot_count == 1",
                variables: {day: "group%{num}_day", time: "group%{num}_start", num: "%{num}"}
            },
            multiple: {
                text: t('static_ivr.appointment_group_menu.generic.multiple'),
                condition: "group%{num}_slot_count > 1",
                variables: {day: "group%{num}_day", start: "group%{num}_start", finish: "group%{num}_finish", num: "%{num}"}
            }
        },
        other: t('static_ivr.appointment_group_menu.other')
    }

    appointment_group_menu1_opts = {
      text: group_text,
      timeout: 5, tries: 1,
      timeout_next: 'other_group_availabilities', invalid_next: 'appointment_menu1',
      parameters: {text_concat_method: 'generic_with_conditions'},
      choices: {key_1: 'group1_action', key_9: 'appointment_menu1'}
    }

    create(Conditional, 'group1_action',
           left_operand: "%{group1_slot_count}", condition: 'gt', right_operand: 1,
           next: 'confirm_group1', invalid_next: 'confirm_single_group1')

    create(Conditional, 'group2_action',
           left_operand: "%{group2_slot_count}", condition: 'gt', right_operand: 1,
           next: 'confirm_group2', invalid_next: 'confirm_single_group2')

    confirm_single_group(1)
    confirm_single_group(2)

    # ADD support for manual better way
    # appointment_group_menu1_opts.deep_merge!(
    #   text: t('static_ivr.appointment_group_menu1_manual', group1),
    #   tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
    #   choices: {key_2: 'other_group_availabilities'}
    # ) if @options[:manual]

    create(Menu, 'appointment_menu1', appointment_group_menu1_opts)

    create(AliasVariable,'confirm_group1',
           parameters: [
             {original: 'group1_date', alias: 'choosen_group'}],
           next: next_node)

    create(AliasVariable,'other_group_availabilities',
           parameters: [{original: 'group1_next', alias: 'group2_next'}],
           next: 'agenda_other_group_availabilities' )


    create(AgendaApi, 'agenda_other_group_availabilities',
           method_name: 'slot_groups',
           parameters: {number_of_groups: 2, after_time: "%{group2_next}",
                        options: {service_id: "%{choosen_service}", resource_id: "%{choosen_resource}"},
                        slot_results: [{start: 'group1_single_start', sid: 'group1_single_sid' },
                                       {start: 'group2_single_start', sid: 'group2_single_sid' }]},
           results: [group1, group2],
           next: 'appointment_menu2')

    appointment_group_menu2_opts = {
        text: group_text,
        timeout: 5, tries: 1,
        timeout_next: 'agenda_other_group_availabilities', invalid_next: 'appointment_menu2',
        parameters: {text_concat_method: 'generic_with_conditions'},
        choices: {key_1: 'group1_action', key_2: 'group2_action', key_3: 'appointment_menu4', key_9: 'appointment_menu2', key_0: 'transfer_or_voicemail'}
    }

    # ADD support for manual better way
    # appointment_group_menu2_opts.deep_merge!(
    #   text: t('static_ivr.appointment_group_menu2_manual', day: 'group1_day', start: 'group1_start', finish: 'group1_finish', time2: 'group2_next'),
    #   tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
    #   choices: {key_3: 'agenda_other_group_availabilities', key_4: 'appointment_menu4'}
    # ) if @options[:manual]

    create(Menu, 'appointment_menu2', appointment_group_menu2_opts)


    create(AliasVariable,'confirm_group2',
           parameters: [{original: 'group2_date', alias: 'choosen_group'}],
           next: next_node)
  end
end