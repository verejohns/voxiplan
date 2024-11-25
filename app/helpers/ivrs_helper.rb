module IvrsHelper
  include InterpolationUtils

  KEY_MAPING = {client_name: :client_first_name, caller_id: :caller_id, appointment_start_time: :choosen_slot_start, choosen_service: :choosen_service, choosen_resource: :choosen_resource, customer_first_name: :customer_first_name, resource_1: :resource_1, resource_2: :resource_2, chat_appointment_start_time: :chat_appointment_start_time}
  # TOOD: switch_to_auto_manual_mode is outdated.
  # We would need to upddate all related methods
  def switch_to_auto_manual_mode(menu1, menu2, menu3, ivr)
    manual = ivr.preference_is_manual?
    save_menu1(menu1, manual)
    save_menu2(menu2, manual)
    save_menu3(menu3, manual)
  end

  def save_menu1(menu1, manual)
    group1 = {day: 'group1_day', start: 'group1_start', finish: 'group1_finish', date: 'group1_date', next_date: 'group1_next'}
    appointment_group_menu1_opts = {
      text: I18n.t('static_ivr.appointment_group_menu1', group1),
      timeout: 5, tries: 1,
      timeout_next: 'other_group_availabilities', invalid_next: 'appointment_menu1',
      choices: {key_1: 'confirm_group1', key_9: 'appointment_menu1'}
    }
    if manual
      appointment_group_menu1_opts.deep_merge!(
        text: I18n.t('static_ivr.appointment_group_menu1_manual', group1),
        tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
        choices: {key_2: 'other_group_availabilities'}
      )
    end
    menu1.update appointment_group_menu1_opts
  end

  def save_menu2(menu2, manual)
    appointment_group_menu2_opts = {
      text: I18n.t('static_ivr.appointment_group_menu2',
              day1: 'group1_day', start1: 'group1_start', finish1: 'group1_finish',
              day2: 'group2_day', start2: 'group2_start', finish2: 'group2_finish'),
      timeout: 5, tries: 1,
      timeout_next: 'agenda_other_group_availabilities', invalid_next: 'appointment_menu2',
      choices: {key_1: 'confirm_group1', key_2: 'confirm_group2', key_3: 'appointment_menu4', key_9: 'appointment_menu2', key_0: 'transfer_or_voicemail'}
    }

    if manual
      appointment_group_menu2_opts.deep_merge!(
        text: I18n.t('static_ivr.appointment_group_menu2_manual',
                day: 'group1_day', start: 'group1_start', finish: 'group1_finish', time2: 'group2_next',
                day1: 'group1_day', start1: 'group1_start', finish1: 'group1_finish',
                day2: 'group2_day', start2: 'group2_start', finish2: 'group2_finish'),
        tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
        choices: {key_3: 'agenda_other_group_availabilities', key_4: 'appointment_menu4'}
      )
    end
    menu2.update appointment_group_menu2_opts
  end

  def save_menu3(menu3, manual)
    appointment_menu3_text = {
      key1: I18n.t('static_ivr.appointment_group_menu3.time1', time1: 'slot1_start'),
      key2: I18n.t('static_ivr.appointment_group_menu3.time2', time2: 'slot2_start'),
      key3: I18n.t('static_ivr.appointment_group_menu3.time3', time3: 'slot3_start'),
      other: I18n.t('static_ivr.appointment_group_menu3.other')
    }

    appointment_menu3_opts = {
      text: appointment_menu3_text,
      timeout: 5, tries: 1,
      timeout_next: 'check_slot_count', invalid_next: 'appointment_menu3',
      parameters: {'time_format': "%{time_format}"},
      choices: {key_1: 'confirm1', key_2: 'confirm2', key_3: 'confirm3', key_9: 'appointment_menu3'}
    }
    if manual
      appointment_menu3_opts.deep_merge!(
        text: appointment_menu3_text.merge(other: I18n.t('static_ivr.appointment_group_menu3.manual_other')),
        tries: 2, timeout_next: 'timeout', invalid_next: 'invalid',
        choices: {key_4: 'check_slot_count'}
      )
    end
    menu3.update appointment_menu3_opts
  end

  def voice_engines
    %w[tropo twilio voxi_sms]
  end

  def save_node(object, params)
    text = nested_merge(object.text, params[:text])
    if object.update(text: text, enabled: params[:enabled].present?)
      flash[:success] = "Your changes were saved!"
    else
      flash[:danger] = object.errors.full_messages
    end
  end

  def res
    Hash.from_xml(@resp)['Response']
  end

  def say
    res['Say']
  end

  def ask_say
    res['Gather']['Say']
  end

  def next_url
    url = res['Gather'].try(:[], 'action') || res['Redirect']
    return unless url
    url += '?' unless url.include? '?'
    url + "&test_idt=#{params[:test_idt]}&cid=#{params[:cid]}&web=1"
  end

  def replace_keys(text)
    data = get_value()

    keys = interpolated_keys(text)
    keys = [keys] if keys.class == Symbol
    p keys
    if keys
      selected_keys = (KEY_MAPING.select {|key, value| keys.include?(key) }).values
      new_data = data.slice(*selected_keys)

      original_key_data= new_data.map {|key, value| [KEY_MAPING.key(key), value]}.to_h
      text % original_key_data
    else
      text
    end
  end

  def get_value(key={})
    data = {client_first_name: "David", caller_id: 33333, chat_appointment_start_time: formatted_time(((Date.today+1.day).to_s+" 16:00:00").to_time), chat_user_name: "Laura", customer_first_name: "Robert", resource_1: "Jackson", resource_2: "Rauba"}

    key.blank? ? data : data[key]
  end
end
