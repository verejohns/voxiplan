# these tasks will run automatically when we run `rake tasks:migrate` in alphabetically order
# We can add a date at the beginning of every task (like rake migrations) to make sure they run
# in desired order like v_2019_07_15_001_task_name
namespace :migrations do
  desc "Sample rake task"
  task v_2019_07_15_001_sample_rake_task: :environment do
    Plan.find_each do |plan|
      # make your changes here
      print "."
    end
  end

  desc "set default user"
  task v_2019_07_15_002_set_default_user: :environment do
    Client.find_each{|client| client.users.find_or_create_by(email: client.email).update(is_default: true) }
  end

  task v_2019_07_16_003_insert_tracking_url_node: :environment do
    nodes = Node.where(name: %w[post_confirmation_reminder])
    nodes.each do |node|

      TrackingURL.create(ivr: node.ivr, name: 'tracking_url', to: "%{caller_id}",
                         can_enable: true, enabled: false,
                         next: 'hang')

      node.update(next: 'tracking_url')
    end
  end

  # Local Resource and Services now belongs to client.
  # this rake task will remove Resource and Services from ivr add will add to clients
  task v_2019_07_20_001_fix_default_resource_and_service: :environment do

    Client.find_each do |client|
      client.send(:set_default_resource_and_service)
    end

    Resource.where(is_default: true, agenda_type: "ClassicAgenda").each do |resource|
      resource.update(eid: resource.ivr.client.default_resource.id, is_default: false)
    end

    Service.where(is_default: true, agenda_type: "ClassicAgenda").each do |service|
      service.update(eid: service.ivr.client.default_service.id, is_default: false)
    end
  end

  task v_2019_07_21_001_update_context_field: :environment do

    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      context = AppointmentBot.new({}).send(:appointment_announcement_context)
      nodes = ivr.nodes.where(name: %w[appointment_announcement_open appointment_announcement_closed])
      nodes.update_all(context: context)

      context = AppointmentBot.new({}).send(:gather_number_context)
      nodes = ivr.nodes.where(name: %w[gather_number])
      nodes.update_all(context: context)

      context = StaticIvr.new({}).send(:announcement_context)
      nodes = ivr.nodes.where(name: %w[announcement_open announcement_closed])
      nodes.update_all(context: context)

      context = StaticIvr.new({}).send(:welcome_context)
      nodes = ivr.nodes.where(name: %w[welcome_open welcome_closed])
      nodes.update_all(context: context)
    end

  end

  task v_2019_09_08_001_create_ai_nodes: :environment do
    Ivr.find_each do |ivr|
      # delete old if there are any
      nodes = ivr.nodes.where(name: %w[ai_bot_start_conversation ai_bot_dialogue ai_bot_gather ai_bot_finish])
      nodes.destroy_all

      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node
      AppointmentBot.new(ivr).send(:create_ai_nodes)
    end
  end

  # we have phone_number and fixed_line_num fields on Customer model, now we allow multiple phone numbers
  # This rake tasks will create a contact for each phone_number
  task v_2019_10_02_001_create_contacts_from_phone_numbers: :environment do
    Customer.order(id: :desc).find_each do |customer|
      customer.contacts.create(phone: customer.phone_number, country: customer.phone_country, phone_type: :mobile, client: customer.client) if customer.phone_number
      customer.contacts.create(phone: customer.fixed_line_num, country: customer.phone_country, phone_type: :fixed_line, client: customer.client) if customer.fixed_line_num
    end
  end

  task v_2019_10_03_001_update_context_field: :environment do

    Ivr.find_each do |ivr|
      I18n.locale = ivr.start_node.locale_from_voice.to_sym if ivr.start_node

      context = StaticIvr.new({}).send(:menu_open_context)
      nodes = ivr.nodes.where(name: %w[menu_open])
      nodes.update_all(context: context)

      context = StaticIvr.new({}).send(:menu_closed_context)
      nodes = ivr.nodes.where(name: %w[menu_closed])
      nodes.update_all(context: context)
    end
  end

  task v_2019_10_17_001_create_phone_numbers_from_identifiers: :environment do
    Identifier.find_each do |idt|
      next unless idt.identifier.scan(/\D/).empty?
      PhoneNumber.create(number: idt.identifier, voice: true)
    end
  end

  task v_2019_10_31_001_fix_ai_node_finish: :environment do
    Node.where(name: %w[ai_bot_dialogue]).find_each do |node|
     node.next_nodes = {
       ai_bot_finish: 'ai_bot_finish'
     }
     node.save
    end
  end

  task v_2019_12_17_001_update_ext_action_appointment_bot: :environment do
    Node.where(name: %w[check_existing_caller]).find_each do |node|
     node.update(ext_action: 'ext_action_appointment_bot')
    end

    Node.where(name: %w[check_caller_id]).find_each do |node|
      node.update(ext_action: nil)
    end
  end

  desc "update default prefrences for shorten urls"
  task v_2019_12_31_001_update_default_prefrences_shorten_urls: :environment do
    Ivr.find_each{|ivr| ivr.preference['shorten_urls'] = false; ivr.save }
  end

  desc "update default prefrences for ai_bot_enabled"
  task v_2019_12_31_002_update_default_prefrences_shorten_urls: :environment do
    Ivr.find_each{|ivr| ivr.preference['ai_bot_enabled'] = false; ivr.save }
  end

  desc "fix data type for calls - use hash instead of String"
  task v_2020_01_13_001_update_missing_fields_for_calls: :environment do
    # All call before ID # 5308 has wrong data type
    calls = Call.where("data = '{}'")
    calls.update_all(data: {})
  end



  desc "Update missing fields for calls"
  task v_2020_01_13_002_update_missing_fields_for_calls: :environment do

    start_date = Date.new(2018, 12, 01)
    end_date = Date.current

    periods = (start_date..end_date).select{|date| date.day == 1}.
        map{|date| [date.beginning_of_month, date.end_of_month]}

    periods.each do |start_date, end_date|
      TwilioUpdateCallsJob.perform_now(start_date.to_s, end_date.to_s)
    end
  end


  task v_2020_03_06_001_update_appointment_success_recorded_node_can_enable: :environment do
    nodes = Node.where(name: %w[appointment_success_recorded])
    nodes.each do |node|
      node.update(can_enable: true)
    end
  end

  task :sms => :environment do
    puts 'Verifying sms capability from twilio'
    twilioclient = Twilio::REST::Client.new(ENV['ACCOUNT_SID'], ENV['AUTH_TOKEN'])
    phone = twilioclient.incoming_phone_numbers.list

    phone.each do |rec|
      ph = PhoneNumber.find_by_number(rec.phone_number)
      sms_capable = rec.capabilities['sms']
      if ph.present?
        ph.sms = sms_capable
        ph.save!
      end
    end
    puts 'Sms capability field updated for respective phone numbers'
  end

  # task :v_2020_05_18_001_remove_duplicate_customer_for_a_client => :environment do
  #   puts 'Delete duplicate contacts for a client'
  #   customers = Customer.all
  #   idss = customers.select("MIN(id) as id").group(:phone_number, :client_id).collect(&:id)
  #   # Customer.where.not(id: idss).destroy_all
  #   puts 'Duplicate Contacts deleted'
  # end

  task :v_2020_05_18_002_move_contact_from_customers_table => :environment do
    puts 'Move contacts from customer table to contacts table'
    customers = Customer.all
    customers.each do |rec|
      rec.contacts.create(phone: rec.phone_number) rescue nil
    end
    puts 'Contacts moved'
  end

  task :v_2020_06_09_001_move_contact_from_customers_table_2 => :environment do
    puts 'Move contacts from customer table to contacts table task 2'
    customers = Customer.all
    customers.each do |rec|
      phone1 = rec.contacts.first.phone rescue nil
      rec.phone_number = phone1 || ''
      rec.save!
    end
    puts 'Contacts moved'
  end

  task :v_2020_06_21_001_chnage_identifier_from_voxiplan_to_voxiai => :environment do
    puts 'Change identifier from voxiplan to voxiai'
    identifiers = Identifier.all
    identifiers.each do |rec|
      rec.identifier = rec.identifier.gsub('voxiplan.com','voxi.ai') if rec.identifier.include? 'voxiplan.com'
      rec.save!
    end
    puts 'Identifiers updated'
  end

  task :v_2020_07_27_001_update_contact_link_with_clients => :environment do
    puts 'Update link of contacts with clients'
    customers = Customer.all
    customers.each do |rec|
      rec.contacts.each do |rec1|
        begin
          rec1.client_id = rec.client_id
          rec1.save!
        rescue => e
          puts e
        end
      end
    end
    puts 'Link Updated!'
  end

  task :v_2020_08_23_001_link_resources_and_services_with_ivrs => :environment do
    puts 'Link Resources and Services with respective IVRs'
    clients = Client.all
    clients.each do |c|
      c.resources.where(ivr_id: nil).update(ivr_id: c.ivrs.first.id)
      c.services.where(ivr_id: nil).update(ivr_id: c.ivrs.first.id)

      c.ivrs.each do |iv|
        iv.resources.where(client_id: nil).update(client_id: c.id)
        iv.services.where(client_id: nil).update(client_id: c.id)
      end
    end
    puts 'Linking done!'
  end

  task :v_2020_09_07_001_include_caller_detail_in_email => :environment do
    puts "update started"
    Node.where(name: 'appointment_success_mail').each do |n|
      unless n.text["caller"].include?("%{email_contact_type}")
        n.text["caller"] = n.text["caller"].gsub("%{caller_id}","%{email_full_name} '%{caller_id}' (%{email_contact_type})")
        n.save!
      end
    end
    Node.where(name: 'hangup_mail').each do |n|
      unless n.text["summary"].include?("%{email_contact_type}")
        n.text["summary"] = n.text["summary"].gsub("%{caller_id}","%{email_full_name} '%{caller_id}' (%{email_contact_type})")
        n.save!
      end
    end
    puts "update ended"
  end

  task :v_2021_03_12_001_enable_add_invitee_option_in_services => :environment do
    puts 'Enable add_invitee option in services'
    services = Service.all
    services.each do |s|
      s.preference["add_invitee"] = "true"
      s.save!
    end
    puts 'Enabling done!'
  end

  desc "Move phone information of customer table to contacts table"
  task :phone_info_to_contacts_table => :environment do
    puts 'Move phone information of customer table to contacts table'
    # customers = Customer.all.where.not(phone_number1: nil).or(Customer.all.where.not(phone_number2: nil)).or(Customer.all.where.not(phone_number3: nil))
    Customer.all.where(is_transfer: false).each do |customer|
      unless customer.phone_number.nil?
        customer.contacts.create(phone: customer.phone_number, country: customer.phone_country, client_id: customer.client_id)
      end
      unless customer.phone_number1.nil?
        customer.contacts.create(phone: customer.phone_number1, country: customer.phone_country1, client_id: customer.client_id)
        customer.phone_number1 = nil
        customer.phone_country1 = nil
      end
      unless customer.phone_number2.nil?
        customer.contacts.create(phone: customer.phone_number2, country: customer.phone_country2, client_id: customer.client_id)
        customer.phone_number2 = nil
        customer.phone_country2 = nil
      end
      unless customer.phone_number3.nil?
        customer.contacts.create(phone: customer.phone_number3, country: customer.phone_country3, client_id: customer.client_id)
        customer.phone_number3 = nil
        customer.phone_country3 = nil
      end
      customer.is_transfer = true
      customer.save
      # puts customer.errors.full_messages
    end
    puts 'Phone information moved'
  end
end