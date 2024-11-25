module ClientsHelper
  def options_for_select_tropo_voice
    TelephonyEngine.voices.map do |tmv|
      ["#{tmv[:voice]}, #{tmv[:gender]}, #{tmv[:language]}", tmv[:voice]]
    end
  end

  def voice_gender_language(voice)
    return unless voice
    options_for_select_tropo_voice.find{|v| v[1] == voice}[0]
  end

  def active_filter_class(filter = nil)
    'm-nav__item--active' if  filter == params[:view]
  end

  def test_identifiers_for_client(client)
    country_code = client.phone_country || client.country_code
    i = TestIdentifier.find_by(country_code: country_code) if country_code.present?
    i ||= TestIdentifier.find_by(country_code: 'US')
    i.try(:identifier)
  end

  def try_agenda_link(agenda_type)
    case agenda_type
      when 'GoogleCalendar'
        'https://calendar.google.com'
      when 'Icloud'
        '#'
      when 'OutlookCalendar'
        'https://office.live.com/start/Calendar.aspx'
      when 'SuperSaas'
        try_agenda_clients_path(type: agenda_type)
      when 'Mobminder'
        '#'
      when 'Timify'
        if current_client.country == 'FR'
          'https://app-fr.timify.com/'
        else
          'https://app-befr.timify.com/'
        end
    end
  end

  def login_agenda_link(agenda_type)
    case agenda_type
      when 'GoogleCalendar'
        'https://calendar.google.com'
      when 'Icloud'
        '#'
      when 'OutlookCalendar'
        'https://office.live.com/start/Calendar.aspx'
      when 'SuperSaas'
        'https://agenda.voxiplan.com/dashboard/login'
      when 'Mobminder'
        connect_your_agenda_integrations_path
      when 'Timify'
        if current_client.country == 'FR'
          'https://app-fr.timify.com/'
        else
          'https://app-befr.timify.com/'
        end
    end
  end

  def agenda_signup_status_class(field)
    'has-danger' if current_client.agenda_sign_up_fields['errors'][field.to_s].present? rescue ''
  end
end
