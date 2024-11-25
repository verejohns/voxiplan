desc "This task is called by the Heroku scheduler add-on"
task :update_calls_from_twilio => :environment do
  puts "Updating calls..."
  start_date = Time.current - 10.minutes
  end_date = Date.current

  TwilioUpdateCallsJob.perform_now(start_date.to_s, end_date.to_s)
  puts "Updating calls done.."
end

desc "This task is called by the Heroku scheduler add-on"
task :renew_conversations => :environment do
  puts "Renew conversations..."

  RenewConversationJob.perform_now

  puts "Renew conversations done.."
end

task :update_billing => :environment do
  puts "Updating billings information"
  if Time.now.day == 1
    start_date = Time.now - 1.month
    BillingJob.perform_now(start_date.to_s, 'save_billing')
  end
  if Time.now.day == 2
    start_date = Time.now
    BillingJob.perform_now(start_date.to_s, 'add_usage_telecom')
  end
  puts "Completed to update billing information"
end

task :send_reminders_for_appointments => :environment do
  puts "Sending Reminders started..."

  AppointmentReminderJob.perform_now
  puts "Reminders Sent..."
end

task :update_contacts_from_agenda => :environment do
  puts 'Update missing details of contacts from agenda to our app'
  customers = Customer.all
  customers.each do |c|
    c.client.ivrs.each do |iv|
      agenda_contact = iv.agenda_app.find_customer(phone: c.phone_number) if c.phone_number
      if iv.agenda_app.type = 'Mobminder' && agenda_contact
        c.first_name = agenda_contact["firstname"] unless c.first_name
        c.last_name = agenda_contact["lastname"] unless c.last_name
        c.email = agenda_contact["email"] unless c.email
        c.gender = agenda_contact["gender"] unless c.gender
        c.birthday = agenda_contact["birthday"] unless c.birthday
        c.city = agenda_contact["city"] unless c.city
        c.street = agenda_contact["address"] unless c.street
        c.zipcode = agenda_contact["zipCode"] unless c.zipcode
        c.fixed_line_num = agenda_contact["phone"] unless c.fixed_line_num
        c.eid = agenda_contact["id"] if c.eid != agenda_contact["id"]
        c.save!
      end
  rescue => exceptions
    puts exceptions

      # if iv.agenda_app.type = 'ClassicAgenda' && agenda_contact
      #   c.first_name = agenda_contact.first_name unless c.first_name
      #   c.last_name = agenda_contact.last_name unless c.last_name
      #   c.email = agenda_contact.email unless c.email
      #   c.gender = agenda_contact.gender unless c.gender
      #   c.birthday = agenda_contact.birthday unless c.birthday
      #   c.city = agenda_contact.city unless c.city
      #   c.street = agenda_contact.street unless c.street
      #   c.zipcode = agenda_contact.zipcode unless c.zipcode
      #   c.phone_country = agenda_contact.phone_country unless c.phone_country
      #   c.notes = agenda_contact.notes unless c.notes
      #   c.recorded_name_url = agenda_contact.recorded_name_url unless c.recorded_name_url
      #   c.fixed_line_num = agenda_contact.fixed_line_num unless c.fixed_line_num
      #   c.created_on_agenda = agenda_contact.created_on_agenda unless c.created_on_agenda
      #   c.country = agenda_contact.country unless c.country
      #   c.save!
      # end
    end
  end

  contacts = Contact.all
  contacts.each do |c|
    c1 = c.customer
    c1.client.ivrs.each do |iv|
      agenda_contact = iv.agenda_app.find_customer(phone: c.phone) if c.phone
      if iv.agenda_app.type = 'Mobminder' && agenda_contact
        c1.first_name = agenda_contact["firstname"] unless c1.first_name
        c1.last_name = agenda_contact["lastname"] unless c1.last_name
        c1.email = agenda_contact["email"] unless c1.email
        c1.gender = agenda_contact["gender"] unless c1.gender
        c1.birthday = agenda_contact["birthday"] unless c1.birthday
        c1.city = agenda_contact["city"] unless c1.city
        c1.street = agenda_contact["address"] unless c1.street
        c1.zipcode = agenda_contact["zipCode"] unless c1.zipcode
        c1.fixed_line_num = agenda_contact["phone"] unless c1.fixed_line_num
        c1.save!
      end
  rescue => exceptions
    puts exceptions

      # if iv.agenda_app.type = 'ClassicAgenda' && agenda_contact
      #   c1.first_name = agenda_contact.first_name unless c1.first_name
      #   c1.last_name = agenda_contact.last_name unless c1.last_name
      #   c1.email = agenda_contact.email unless c1.email
      #   c1.gender = agenda_contact.gender unless c1.gender
      #   c1.birthday = agenda_contact.birthday unless c1.birthday
      #   c1.city = agenda_contact.city unless c1.city
      #   c1.street = agenda_contact.street unless c1.street
      #   c1.zipcode = agenda_contact.zipcode unless c1.zipcode
      #   c1.phone_country = agenda_contact.phone_country unless c1.phone_country
      #   c1.notes = agenda_contact.notes unless c1.notes
      #   c1.recorded_name_url = agenda_contact.recorded_name_url unless c1.recorded_name_url
      #   c1.fixed_line_num = agenda_contact.fixed_line_num unless c1.fixed_line_num
      #   c1.created_on_agenda = agenda_contact.created_on_agenda unless c1.created_on_agenda
      #   c1.country = agenda_contact.country unless c1.country
      #   c1.save!
      # end
    end
  end
  puts 'Updating done!'
end