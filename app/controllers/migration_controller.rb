class MigrationController < ApplicationController
  include ApplicationHelper

  def remove_clients
    redirect_to root_path and return if ENV['APP_ENV'] == 'prod' || params[:keyword].nil? || params[:keyword].blank?

    Client.where('email like ?', "#{params[:keyword]}%").each do |client|
      next if client.email.include?('websoft') || client.email.include?('@voxiplan.com') || client.email.include?('@voxi.ai') ||
        client.email.include?('bigfire') || client.email.include?('ruba') || client.email.include?('axelboven')
      client.ivrs.each do |ivr|
        VoxiSession.where(ivr_id: ivr.id).destroy_all
        AgendaApp.where(ivr_id: ivr.id).destroy_all
      end

      client.destroy
    end

    redirect_to root_path
  end

  def migrate_chargebee
    ISO3166.configuration.enable_currency_extension!
    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    Client.all.each do |client|
      country = ISO3166::Country[client.phone_country]
      currency_code = country.currency.iso_code == 'EUR' ? 'EUR' : 'USD'
      client.update_columns(currency_code: currency_code)

      next if client.organizations.count.zero?
      organization = client.organizations.first
      if organization.chargebee_seats.nil?
        result = ChargeBee::Customer.create({
                  :id => organization.id,
                  :first_name => client.first_name,
                  :last_name => client.last_name,
                  :company => organization.name,
                  :email => client.email,
                  :locale => I18n.locale
                })
        result = ChargeBee::Subscription.create_with_items(result.customer.id,{
          :subscription_items => [{:item_price_id => ENV["PREMIUM_TRIAL_#{currency_code}_ID"]}]
        })
        organization.update_columns(chargebee_seats: 1, chargebee_subscription_id: result.subscription.id, chargebee_subscription_plan: 'trial', chargebee_subscription_period: 'monthly')
      end
    end

    redirect_to root_path
  end

  def migrate_reminder_time
    Reminder.where.not(time: '').each do |reminder|
      time = reminder.time
      next if time[3..-1] == '00' || time[3..-1] == '30'
      new_time = time[0, 3] + '00' if time[3..-1] == '10'
      new_time = time[0, 3] + '30' if time[3..-1] == '20' || time[3..-1] == '40'
      new_time = (time[0, 2].to_i + 1).to_s.rjust(2, '0')  + ':00' if time[3..-1] == '50'
      reminder.time = new_time
      reminder.save
    end

    redirect_to root_path
  end

  def migrate_agenda_app_organization
    AgendaApp.all.each do |agenda_app|
      if agenda_app.organization_id.nil? && agenda_app.client_id
        client = Client.find(agenda_app.client_id)

        agenda_app.update_columns(organization_id: client.organizations.first.id) if client && client.organizations.count
      end
    end

    redirect_to root_path
  end

  def migrate_phone_info
    phone_list = PhoneNumber.all
    phones = phone_list.select{ |p| p }
    phones.each do |phone|
      id = Identifier.find_by_identifier(phone.number.gsub('+', ''))
      next unless id
      next if id.phone_price.present?

      phone_info = twilioclient.lookups.v1.phone_numbers(phone.number).fetch(type: ['carrier'])
      phone_country_code = phone_info.country_code
      phone_type = phone_info.carrier['type']
      phone_type = 'local' if phone_type == 'landline' || phone_type.nil?
      phone_type = 'local' if phone.number == '+3242771299'
      phone_type = 'local' if %w[+16505055800 +19085035893 +19292079050].include? phone.number
      phone_type = 'national' if phone.number == '+3278250303'
      phone_type = 'national' if %w[+33971071001 +33971080777 +33974991967 +33974994424 +33974996510 +33974999261 +33978460101 +33980091887].include? phone.number

      pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))
      phone_data = pricing_details.symbolize_keys[:phone_number]

      default_phone_margin = fetch_phone_margin(phone_data)
      user_phone_margin = nil
      user_phone_margin = fetch_phone_margin(phone_data[country_code]) if phone_data.include? phone_country_code

      phone_margin = user_phone_margin.nil? || user_phone_margin[:local].nil? ? default_phone_margin[:local] : user_phone_margin[:local] if phone_type == 'local'
      phone_margin = user_phone_margin.nil? || user_phone_margin[:mobile].nil? ? default_phone_margin[:mobile] : user_phone_margin[:mobile] if phone_type == 'mobile'
      phone_margin = user_phone_margin.nil? || user_phone_margin[:national].nil? ? default_phone_margin[:national] : user_phone_margin[:national] if phone_type == 'national'

      phone_margin = fetch_margin_val(phone_margin.to_i)
      twilio_price = 0
      twilio_price = 1.25 if phone.number == '+3242771299' || phone.number == '+3278250303'
      twilio_price = 1.15 if %w[+33971071001 +33971071080 +33971080777 +33974991967 +33974994424 +33974996510 +33974999261 +33978460101 +33980091887].include? phone.number
      twilio_price = 1.15 if %w[+16505055800 +19085035893 +19292079050].include? phone.number

      if twilio_price.zero?
        phone_prices = twilioclient.pricing.v1.phone_numbers.countries(phone_country_code).fetch
        (phone_prices&.phone_number_prices || []).each do |data|
          twilio_price = data['base_price'].to_f if data['number_type'] == phone_type
        end
      end
      id.phone_type = phone_type
      id.phone_price = (twilio_price * phone_margin).round(2)
      id.save
    end
    redirect_to root_path
  end

  def migrate_service
    puts '****** migrating about eid is NULL ******'
    Service.where("eid IS NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |service|
      service.agenda_type = nil
      service.client_id = service.client.id
      service.name = 'Unknown' if service.name.nil?
      service.order_id = 1 if service.order_id.nil?
      service.save

      service_dup = Service.find_by(eid: service.id)
      if service_dup.nil?
        service_dup = Service.new(ivr_id: service.ivr_id, enabled: service.enabled, is_default: service.is_default,
                                  name: service.name, ename: service.ename, eid: service.id, client_id: service.client_id,
                                  is_local: service.is_local, availability: service.availability.to_json, preference: service.preference,
                                  order_id: service.order_id + 1, schedule_template_id: service.schedule_template_id,
                                  overrides: service.overrides, duration: service.duration, response_format: service.response_format,
                                  start_interval: service.start_interval, resource_distribution: service.resource_distribution,
                                  use_default_availability: service.use_default_availability)
        service_dup.preference[:ai_phone_assistant_enabled] = false
        service_dup.save
      end
      Service.where(id: service_dup.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{service.id} - #{service_dup.id}"
    end

    puts '****** migrating about eid is same with id ******'
    Service.where("eid IS NOT NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |service|
      next unless service.id.to_s == service.eid

      service.eid = nil
      service.agenda_type = nil
      service.client_id = service.client.id
      service.name = 'Unknown' if service.name.nil?
      service.order_id = 1 if service.order_id.nil?
      service.save

      service_dup = Service.find_by(eid: service.id)
      if service_dup.nil?
        service_dup = Service.new(ivr_id: service.ivr_id, enabled: service.enabled, is_default: service.is_default,
                                  name: service.name, ename: service.ename, eid: service.id, client_id: service.client_id,
                                  is_local: service.is_local, availability: service.availability.to_json, preference: service.preference,
                                  order_id: service.order_id + 1, schedule_template_id: service.schedule_template_id,
                                  overrides: service.overrides, duration: service.duration, response_format: service.response_format,
                                  start_interval: service.start_interval, resource_distribution: service.resource_distribution,
                                  use_default_availability: service.use_default_availability)
        service_dup.preference[:ai_phone_assistant_enabled] = false
        service_dup.save
      end
      Service.where(id: service_dup.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{service.id} - #{service_dup.id}"
    end

    puts '****** migrating about eid is not NULL ******'
    Service.where("eid IS NOT NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |service|
      service.name = 'Unknown' if service.name.nil?
      service.order_id = 2 if service.order_id.nil?
      service.save

      service_org = Service.find_by(id: service.eid)
      if service_org.nil?
        service_org = Service.new(id: service.eid, ivr_id: service.ivr_id, enabled: service.enabled, is_default: service.is_default,
                                  name: service.name, ename: service.ename, eid: nil, client_id: service.client.id,
                                  is_local: service.is_local, availability: service.availability.to_json, preference: service.preference,
                                  order_id: service.order_id - 1, schedule_template_id: service.schedule_template_id,
                                  overrides: service.overrides, duration: service.duration, response_format: service.response_format,
                                  start_interval: service.start_interval, resource_distribution: service.resource_distribution,
                                  use_default_availability: service.use_default_availability)
        service_org.preference[:ai_phone_assistant_enabled] = false
        service_org.preference[:phone_assistant_enabled] = true
        service_org.save

        question = service_org.questions.new(text: 'first_lastname', answer_type: 'mandatory', enabled: true)
        question.save
        puts '****** migrated ******'
      end
      Service.where(id: service.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{service_org.id} - #{service.id}"
    end

    Service.all.each do |service|
      service.ename = service.name if service.ename.nil? || service.ename.blank?
      service.preference['widget_enabled'] = true unless service.client_id.nil?
      service.preference['widget_enabled'] = false if service.client_id.nil?
      service.save
    end

    Service.where(agenda_type: nil).each do |service|
      if service.questions.where(answer_type: 'mandatory').count.zero?
        question = service.questions.new(text: 'first_lastname', answer_type: 'mandatory', enabled: true)
        question.save
      end

      unless service.reminder
        email_invitee_subject = t('mails.reminder_email_invitee.subject')
        email_invitee_body = t('mails.reminder_email_invitee.body')
        sms_invitee_body = t('mails.reminder_sms_invitee.body')
        Reminder.create(advance_time_offset: 10, advance_time_duration: '-', time: '', sms: false, email: false, email_subject: email_invitee_subject, text: email_invitee_body, email_subject_host: email_invitee_subject, text_host: email_invitee_body,
                        sms_text: sms_invitee_body, client_id: client.id, ivr_id: service.ivr_id, service_id: service.id, enabled: true, is_include_agenda: false)
      end
    end

    redirect_to root_path
  end

  def migrate_resource
    puts '****** migrating about eid is NULL ******'
    Resource.where("eid IS NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |resource|
      resource.agenda_type = nil
      resource.client_id = resource.client.id
      resource.name = 'Unknown' if resource.name.nil?
      resource.save

      resource_dup = Resource.find_by(eid: resource.id)
      if resource_dup.nil?
        resource_dup = Resource.new(ivr_id: resource.ivr_id, enabled: resource.enabled, is_default: resource.is_default,
                                    name: resource.name, ename: resource.ename, eid: resource.id, client_id: resource.client_id,
                                    is_local: resource.is_local, availability: resource.availability, preference: resource.preference)
        resource_dup.save
      end
      Resource.where(id: resource_dup.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{resource.id} - #{resource_dup.id}"
    end

    puts '****** migrating about eid is id ******'
    Resource.where("eid IS NOT NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |resource|
      next unless resource.id.to_s == resource.eid

      resource.eid = nil
      resource.agenda_type = nil
      resource.client_id = resource.client.id
      resource.name = 'Unknown' if resource.name.nil?
      resource.save

      resource_dup = Resource.find_by(eid: resource.id)
      if resource_dup.nil?
        resource_dup = Resource.new(ivr_id: resource.ivr_id, enabled: resource.enabled, is_default: resource.is_default,
                                    name: resource.name, ename: resource.ename, eid: resource.id, client_id: resource.client_id,
                                    is_local: resource.is_local, availability: resource.availability, preference: resource.preference)
        resource_dup.save
      end
      Resource.where(id: resource_dup.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{resource.id} - #{resource_dup.id}"
    end

    puts '****** migrating about eid is not NULL ******'
    Resource.where("eid IS NOT NULL AND (agenda_type IS NULL OR agenda_type='ClassicAgenda')").each do |resource|
      if resource.name.nil?
        resource.name = 'Unknown'
        resource.save
      end
      resource_org = Resource.find_by(id: resource.eid)
      if resource_org.nil?
        resource_org = Resource.new(id: resource.eid, ivr_id: resource.ivr_id, enabled: resource.enabled, is_default: resource.is_default,
                                    name: resource.name, ename: resource.ename, eid: nil, client_id: resource.client.id,
                                    is_local: resource.is_local, availability: resource.availability, preference: resource.preference)
        resource_org.save
        puts '****** migrated ******'
      end
      Resource.where(id: resource.id).update_all(client_id: nil, agenda_type: 'ClassicAgenda')
      puts "#{resource_org.id} - #{resource.id}"
    end

    Resource.all.update_all(calendar_type: 'my_calendar')
    Resource.all.update_all(calendar_id: nil)
    Resource.where(ename: nil).each do |resource|
      resource.ename = resource.name
      resource.save
    end

    redirect_to root_path
  end

  def default_init
    Client.all.each do |client|
      if client
        if client.schedule_templates.count.zero?
          schedule_template = client.schedule_templates.new(template_name: t('availabilities.working_hours'), is_default: true)
          schedule_template.save
          availablities = Availability.new(schedule_template_id: schedule_template.id)
          availablities.save
        end

        if client.calendar_setting.nil?
          calendar_setting = CalendarSetting.new(client_id: client.id, max_time: '23:55:00')
          calendar_setting.save
        end

      else
        puts "****** There is no exist the client on database (id: #{old_client["id"]}) ******"
      end
    end

    AgendaApp.where(type: 'ClassicAgenda').destroy_all
    AgendaApp.where(type: 'DummyAgenda').destroy_all
    AgendaApp.all.each do |agenda_app|
      ivr = Ivr.find(agenda_app.ivr_id)
      agenda_app.update_attributes(client_id: ivr.client.id) if ivr && agenda_app.client_id.nil?
    end

    Ivr.find_each do |ivr|
      widget_level1_dropdown = ivr.preference["widget_level1_dropdown"] || 'Custom Order'
      widget_dropdown_default_resource = ivr.preference["widget_dropdown_default_resource"] || 'serviceFirst'

      if widget_level1_dropdown == 'Custom Order' && widget_dropdown_default_resource == 'serviceFirst'
        ivr.services.each do |service|
          service.update_columns(resource_distribution: 'invitee') if service.client_id
        end
      end

      if widget_level1_dropdown == '-' || widget_level1_dropdown == 'Service Only'
        if widget_level1_dropdown == 'Service Only'
          ivr.services.where.not(client_id: nil).each do |service|
            if service.resources.count > 1
              service.update_columns(resource_distribution: 'random')
            else
              service.update_columns(resource_distribution: 'one')
            end
          end
        end

        ivr.preference['widget_level1_dropdown'] = 'Custom Order'
        ivr.preference['widget_dropdown_default_resource'] = 'serviceFirst'
        ivr.save
      end


      if ivr.voice_locale.include? 'en'
        message = 'en-US-Neural2-F'
        message_locale = 'en-US'
      else
        message = ivr.voice
        message_locale = ivr.voice_locale
      end

      ivr.update_columns(booking_url: ivr.uid, message: message, message_locale: message_locale)

      organization = Organization.find_by_client_id(ivr.client.id)
      ivr.update_columns(organization_id: organization.id) if organization

      nodes = ivr.nodes.where(left_operand: "user_says")

      nodes.each do |node|
        if ivr.assistant_name == "Laura"
          node.update_columns(right_operand: "/greet{'client_identifier': '#{ivr.uid}', 'language': '#{message_locale[0..1]}'}")
        else
          node.update_columns(right_operand: "/greet{'client_identifier': '#{ivr.uid}', 'language': '#{message_locale[0..1]}', 'assistant_name': '#{ivr.assistant_name}'}")
        end
      end

      ivr.reminder.each do |reminder|
        reminder.update_columns(is_include_cancel_link: true)
      end

      if ivr.google_voice_locale.blank?
        google_voice_locale = ivr.voice_locale + '-' + ivr.client.country_code
        google_languages = CSV.parse(File.read(File.expand_path('db/google_language.csv')), headers: true)
        google_language_locales = google_languages.by_col[1]
        google_voice_locale = map_lang(ivr.voice_locale) unless google_language_locales.include? google_voice_locale
        ivr.update_columns(google_voice_locale: google_voice_locale)
      end
    end

    redirect_to root_path
  rescue => e
    puts e.message
    puts "****** The existed client's default setting is failure ******"
  end

  def map_lang(lang)
    case lang
    when 'en'
      'en-US'
    when 'fr'
      'fr-FR'
    when 'de'
      'de-DE'
    when 'it'
      'it-IT'
    when 'es'
      'es-ES'
    else
      lang
    end
  end

end
