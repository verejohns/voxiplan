class Fifo < AppointmentBot
  def menu1(start_node: , next_node:)
    agenda_availabilities_opts = {
      method_name: 'free_slots',
      parameters: {number_of_slots: 1, after_time: "%{current_time}",
                   options: {service_id: "%{choosen_service}", resource_id: "%{choosen_resource}"}},
      results: [{start: 'slot1_start', sid: 'slot1_sid' }],
      next: 'appointment_menu1'
    }

    # agenda_availabilities_opts.merge(
    #   {
    #     after_time: "%{choosen_group}",
    #     options: {full_day: true}
    #   }) if by_preference?

    create(AgendaApi, start_node, agenda_availabilities_opts)

    appointment_menu1_opts = {
      text: t('static_ivr.appointment_menu1', time1: 'slot1_start'),
      timeout: 5, tries: 1,
      timeout_next: next_node, invalid_next: 'appointment_menu1',
      choices: {key_1: 'confirm1', key_9: 'appointment_menu1'}
    }

    appointment_menu1_opts.merge!(
      text: t('static_ivr.appointment_menu1_manual', time1: 'slot1_start'),
      tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
      choices: {key_2: next_node}
    ) if @options[:manual]

    create(Menu, 'appointment_menu1', appointment_menu1_opts)
  end

  def menu2(start_node: , next_node:)
    create(AgendaApi, start_node,
           method_name: 'free_slots',
           parameters: {number_of_slots: 2, after_time: "%{slot2_start}"},
           results: [{start: 'slot1_start', sid: 'slot1_sid' },
                     {start: 'slot2_start', sid: 'slot2_sid' }],
           next: 'appointment_menu2')


    appointment_menu2_opts = {
      text: t('static_ivr.appointment_menu2', time1: 'slot1_start', time2: 'slot2_start'),
      timeout: 5, tries: 1,
      timeout_next: next_node, invalid_next: 'appointment_menu2',
      choices: {key_1: 'confirm1', key_2: 'confirm2', key_9: 'appointment_menu2', key_0: 'transfer_or_voicemail'}
    }

    appointment_menu2_opts.merge!(
      text: t('static_ivr.appointment_menu2_manual', time1: 'slot1_start', time2: 'slot2_start'),
      tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
      choices: {key_3: next_node}
    ) if @options[:manual]

    create(Menu, 'appointment_menu2', appointment_menu2_opts)
  end

  def build
    res_ser_next = resource_and_services(next_node: 'tries_count')
    caller_id_and_announcement(next_node: res_ser_next)
    create_variable(name: 'tries_count', value: 1, next_node: 'agenda_availabilities')
    menu1(start_node: 'agenda_availabilities', next_node: 'other_availabilities' )
    increment_tries(start_node: 'increment_tries', next_node: 'agenda_other_availabilities', variable_name: 'tries_count')

    create(AliasVariable,'other_availabilities',
           parameters: [{original: 'slot1_start', alias: 'slot2_start'}],
           next: 'increment_tries' )

    menu2(start_node: 'agenda_other_availabilities', next_node: 'increment_tries')

    confirm(1)
    confirm(2)

    make_appointment
    transfer_or_voicemail

    START
  end
end