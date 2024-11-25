require 'money/bank/uphold'

class BillingJob < ApplicationJob
  include ApplicationHelper

  queue_as :default

  def perform(start_time, flag)
    from_time = DateTime.parse(start_time).beginning_of_month
    to_time = DateTime.parse(start_time).end_of_month

    save_billing_info(from_time, to_time) if flag == 'save_billing'
    add_usage_telecom(from_time, to_time) if flag == 'add_usage_telecom'
  end

  def add_usage_telecom(start_time, end_time)
    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])

    Client.where(confirmation_sms: true, is_welcomed: true).each do |client|
      query = "SELECT sum(quantity) as appointment_nums FROM billings WHERE client_id=#{client.id} AND category = 'appointment' AND
          created_at BETWEEN '#{start_time.strftime('%Y-%m-%d %H:%M:%S')}' AND '#{end_time.strftime('%Y-%m-%d %H:%M:%S')}'"
      appointment = ActiveRecord::Base.connection.exec_query(query)
      appointment_nums = appointment.count.zero? ? 0 : appointment.first['appointment_nums'].to_i

      query = "SELECT sum(quantity) as task_nums FROM billings WHERE client_id=#{client.id} AND category = 'task' AND
          created_at BETWEEN '#{start_time.strftime('%Y-%m-%d %H:%M:%S')}' AND '#{end_time.strftime('%Y-%m-%d %H:%M:%S')}'"
      task = ActiveRecord::Base.connection.exec_query(query)
      task_nums = task.count.zero? ? 0 : task.first['task_nums'].to_i

      query = "SELECT sum(selling_price) as amount FROM billings WHERE client_id=#{client.id} AND category != 'task' AND category != 'appointment' AND
          category != 'seat' AND category != 'phone' AND created_at BETWEEN '#{start_time.strftime('%Y-%m-%d %H:%M:%S')}' AND '#{end_time.strftime('%Y-%m-%d %H:%M:%S')}'"
      telecom = ActiveRecord::Base.connection.exec_query(query)
      telecom_amount = telecom.count.zero? ? 0 : telecom.first['amount'].to_f * 100

      unless client.organizations.first.chargebee_subscription_id.nil?

        # add usage for appointment
        if appointment_nums > 0
          result = ChargeBee::Usage.create(client.organizations.first.chargebee_subscription_id,{
            :item_price_id => ENV["APPOINTMENT_#{client.currency_code}_ID"],
            :usage_date => end_time.to_i,
            :note => "Usage of appointments",
            :quantity => appointment_nums.to_s
          })
          puts result
        end

        # add usage for task
        if task_nums > 0
          result = ChargeBee::Usage.create(client.organizations.first.chargebee_subscription_id,{
            :item_price_id => ENV["TASK_#{client.currency_code}_ID"],
            :usage_date => end_time.to_i,
            :note => "Usage of tasks",
            :quantity => task_nums.to_s
          })
          puts result
        end

        # add charge for telecom
        if telecom_amount > 0
          result = ChargeBee::UnbilledCharge.create({
            :subscription_id => client.organizations.first.chargebee_subscription_id,
            :currency_code => client.currency_code,
            :item_prices => [{ :item_price_id => ENV["TELECOM_#{client.currency_code}_ID"] }],
            :charges => [
              {:amount => telecom_amount.to_i, :description => "charge for telecom", :date_from => start_time.to_i, :date_to => end_time.to_i}
            ]
          })
          puts result
        end
      end
    end
  rescue => e
    puts "====== Rescue: add_usage_telecom ======"
    puts e
  end

  def save_billing_info(start_time, end_time)
    euro_rate = fetch_eur_rate
    twilioclient = Twilio::REST::Client.new(ENV['ACCOUNT_SID'], ENV['AUTH_TOKEN'])

    Client.where(confirmation_sms: true, is_welcomed: true).each do |client|
      user_country = fetch_user_country(client)
      user_country_code = user_country.downcase

      pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))

      appointment_pricing = pricing_details.symbolize_keys[:appointments]
      sip_data = pricing_details.symbolize_keys[:sip]
      voice_data = pricing_details.symbolize_keys[:voice]
      sms_data = pricing_details.symbolize_keys[:sms]
      phone_data = pricing_details.symbolize_keys[:phone_number]

      # get margin for voice
      default_voice_margin = fetch_voice_margin(voice_data)
      user_voice_margin = nil
      if voice_data.include? user_country_code
        user_voice_margin = fetch_voice_margin(voice_data[user_country_code])
      end
      voice_inbound_local_margin = user_voice_margin.nil? || user_voice_margin[:inbound_local].nil? ? default_voice_margin[:inbound_local] : user_voice_margin[:inbound_local]
      voice_inbound_mobile_margin = user_voice_margin.nil? || user_voice_margin[:inbound_mobile].nil? ? default_voice_margin[:inbound_mobile] : user_voice_margin[:inbound_mobile]
      voice_outbound_margin = user_voice_margin.nil? || user_voice_margin[:outbound].nil? ? default_voice_margin[:outbound] : user_voice_margin[:outbound]
      voice_inbound_local_margin = fetch_margin_val(voice_inbound_local_margin.to_i)
      voice_inbound_mobile_margin = fetch_margin_val(voice_inbound_mobile_margin.to_i)
      voice_outbound_margin = fetch_margin_val(voice_outbound_margin.to_i)

      # get margin for sms
      default_sms_margin = fetch_sms_margin(sms_data)
      user_sms_margin = nil
      if sms_data.include? user_country_code
        user_sms_margin = fetch_sms_margin(sms_data[user_country_code])
      end
      sms_inbound_margin = user_sms_margin.nil? || user_sms_margin[:inbound].nil? ? default_sms_margin[:inbound] : user_sms_margin[:inbound]
      sms_outbound_margin = user_sms_margin.nil? || user_sms_margin[:outbound].nil? ? default_sms_margin[:outbound] : user_sms_margin[:outbound]
      sms_inbound_margin = fetch_margin_val(sms_inbound_margin.to_i)
      sms_outbound_margin = fetch_margin_val(sms_outbound_margin.to_i)

      # get margin for phone number
      default_phone_margin =  fetch_phone_margin(phone_data)
      user_phone_margin = nil
      if phone_data.include? user_country_code
        user_phone_margin = fetch_phone_margin(phone_data[user_country_code])
      end
      phone_national_margin = user_phone_margin.nil? || user_phone_margin[:national].nil? ? default_phone_margin[:national] : user_phone_margin[:national]
      phone_local_margin = user_phone_margin.nil? || user_phone_margin[:local].nil? ? default_phone_margin[:local] : user_phone_margin[:local]
      phone_mobile_margin = user_phone_margin.nil? || user_phone_margin[:mobile].nil? ? default_phone_margin[:mobile] : user_phone_margin[:mobile]
      phone_national_margin = fetch_margin_val(phone_national_margin.to_i)
      phone_local_margin = fetch_margin_val(phone_local_margin.to_i)
      phone_mobile_margin = fetch_margin_val(phone_mobile_margin.to_i)

      # get margin for SIP
      sip_margin = sip_data.include?(user_country_code) ? fetch_margin_val(sip_data[user_country_code].to_i) : fetch_margin_val(sip_data[:margin].to_i)

      client.ivrs.each do |ivr|
        @task_count = 0

        @sip_twilio_cost = 0
        @sip_cost = 0

        @incoming_mobile_duration = 0
        @incoming_mobile_twilio_cost = 0
        @incoming_mobile_cost = 0

        @incoming_local_duration = 0
        @incoming_local_twilio_cost = 0
        @incoming_local_cost = 0

        @outgoing_duration = 0
        @outgoing_twilio_cost = 0
        @outgoing_cost = 0

        tasks = ivr.calls.where("phone_price > 0 AND phone_price IS NOT NULL AND created_at BETWEEN ? AND ?", start_time, end_time)

        tasks.each do |call|
          if call.call_type == 'incoming' && call.phone_type == 'mobile'
            @incoming_mobile_duration += call.duration
            @incoming_mobile_twilio_cost += call.phone_price
            @incoming_mobile_cost += call.sale_price
          end

          if call.call_type == 'incoming' && call.phone_type == 'local'
            @incoming_local_duration += call.duration
            @incoming_local_twilio_cost +=  call.phone_price
            @incoming_local_cost += call.sale_price
          end

          if call.call_type == 'outgoing'
            @outgoing_duration += call.duration
            @outgoing_twilio_cost +=  call.phone_price
            @outgoing_cost += call.sale_price
          end

          if call.is_sip == true
            @sip_twilio_cost += call.phone_price
            @sip_cost += call.sale_price
          end

        end

        # VoxiSessions for billing
        voxi_sessions = VoxiSession.where("ivr_id = ? AND created_at BETWEEN ? AND ?", ivr.id, start_time, end_time)
        @task_count = @task_count + voxi_sessions.count

        # conversations for billing
        @task_count = @task_count + ivr.conversations.where("created_at BETWEEN ? AND ?", start_time, end_time).count

        # Get the billing values for Tasks
        @task_count = @task_count + tasks.count
        @task_cost = @task_count > 50 ? (0.01 * (@task_count - 50)).ceil(2) : 0

        # Get the billing values for Appointment
        confirmed_widget_appointments = ivr.appointments.where('status = ? AND source != ? AND created_at BETWEEN ? AND ?', 'Confirmed', 'IVR', start_time, end_time).count
        cancelled_widget_appointments = 0
        ivr.appointments.where("status = ? AND source != ? AND created_at BETWEEN ? AND ?", 'Cancelled', 'IVR', start_time, end_time).each do |cancelled_widget_appointment|
          cancelled_widget_appointments = cancelled_widget_appointments + (cancelled_widget_appointment.rescheduled_count || 0) + 2
        end
        rescheduled_widget_appointments = 0
        ivr.appointments.where("status = ? AND source != ? AND created_at BETWEEN ? AND ?", 'Rescheduled', 'IVR', start_time, end_time).each do |rescheduled_widget_appointment|
          rescheduled_widget_appointments = rescheduled_widget_appointments + rescheduled_widget_appointment.rescheduled_count + 1
        end
        @appointments = ivr.calls.where("appointment_type IS NOT NULL AND call_for_appointment = ? AND created_at BETWEEN ? AND ?", true, start_time, end_time).count + confirmed_widget_appointments + rescheduled_widget_appointments + cancelled_widget_appointments
        @appointments_cost = (appointment_pricing[:first_x] * @appointments).ceil(2) if @appointments <= 100
        @appointments_cost = (appointment_pricing[:first_x] * 100 + appointment_pricing[:next_y] * (@appointments - 100)).ceil(2) if @appointments > 100 && @appointments <= 250
        @appointments_cost = (appointment_pricing[:first_x] * 100 + appointment_pricing[:next_y] * 150 + appointment_pricing[:next_z] * (@appointments - 250)).ceil(2) if @appointments > 250

        # Get the billing values for SMS
        @sms_inbound_segments = 0
        @sms_inbound_twilio_cost = 0
        @sms_inbound_cost = 0

        @sms_outbound_segments = 0
        @sms_outbound_twilio_cost = 0
        @sms_outbound_cost = 0

        ivr.text_messages.where("sms_price > 0 AND sms_price IS NOT NULL AND created_at BETWEEN ? AND ?", start_time, end_time).each do |message|
          if message.incoming == true
            @sms_inbound_segments += message.segment
            @sms_inbound_twilio_cost += message.sms_price
            @sms_inbound_cost += message.sale_price
          end
          if message.incoming == false || message.incoming.nil?
            @sms_outbound_segments += message.segment
            @sms_outbound_twilio_cost += message.sms_price
            @sms_outbound_cost += message.sale_price
          end
        end

        # Get the billing values for Phone Numbers
        @phone_local_nums = 0
        @phone_mobile_nums = 0
        @phone_national_nums = 0
        @phone_local_twilio_cost = 0
        @phone_mobile_twilio_cost = 0
        @phone_national_twilio_cost = 0

        ivr.identifiers.where("created_at BETWEEN ? AND ?", start_time, end_time).each do |id|
          identifier = id.identifier.scan(/\D/).empty? ? "+#{id.identifier}" : id.identifier
          next if PhoneNumber.where(number: identifier, created_at: start_time..end_time).count.zero?

          phone_type = id.phone_type
          phone_price = id.phone_price

          phone_type = 'local' if phone_type == 'landline'
          @phone_local_nums += 1 if phone_type == 'local'
          @phone_mobile_nums += 1 if phone_type == 'mobile'
          @phone_national_nums += 1 if phone_type == 'national'

          @phone_local_twilio_cost += phone_price if phone_type == 'local'
          @phone_mobile_twilio_cost += phone_price if phone_type == 'mobile'
          @phone_national_twilio_cost += phone_price if phone_type == 'national'
        end

        @phone_local_cost = (@phone_local_twilio_cost * @phone_local_nums * phone_local_margin).ceil(2)
        @phone_mobile_cost = (@phone_mobile_twilio_cost * @phone_mobile_nums * phone_mobile_margin).ceil(2)
        @phone_national_cost = (@phone_national_twilio_cost * @phone_national_nums * phone_national_margin).ceil(2)

        monthly_price = 10
        annually_price = 8
        if client.organizations.first && (client.organizations.first.chargebee_subscription_plan == "premium" || client.organizations.first.chargebee_subscription_plan == "custom")
          monthly_price = 15
          annually_price = 12
        end
        seat_price = client.organizations.first && client.organizations.first.chargebee_subscription_period == 'monthly' ? monthly_price : annually_price
        @seat_nums = ivr.resources.where('agenda_type IS NOT NULL AND enabled=true AND created_at BETWEEN ? AND ?', start_time, end_time).count
        @seat_cost = @seat_nums * seat_price

        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'task', phone_type: '', cost_price: 0, cost_price_unit: '', profit_margin: 0, quantity: @task_count,
                              selling_price: @task_cost, selling_price_unit: 'USD', selling_price_eur: (@task_cost * euro_rate).ceil(2))
        billing.save

        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'appointment', phone_type: '', cost_price: 0, cost_price_unit: '', profit_margin: 0, quantity: @appointments,
                              selling_price: @appointments_cost, selling_price_unit: 'USD', selling_price_eur: (@appointments_cost * euro_rate).ceil(2))
        billing.save

        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'voice_inbound', phone_type: 'local', cost_price: @incoming_local_twilio_cost.abs, cost_price_unit: 'USD',
                              profit_margin: voice_inbound_local_margin, quantity: @incoming_local_duration,
                              selling_price: @incoming_local_cost, selling_price_unit: 'USD', selling_price_eur: (@incoming_local_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'voice_inbound', phone_type: 'mobile', cost_price: @incoming_mobile_twilio_cost.abs, cost_price_unit: 'USD',
                              profit_margin: voice_inbound_mobile_margin, quantity: @incoming_mobile_duration,
                              selling_price: @incoming_mobile_cost, selling_price_unit: 'USD', selling_price_eur: (@incoming_mobile_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'voice_outbound', phone_type: '', cost_price: @outgoing_twilio_cost.abs, cost_price_unit: 'USD',
                              profit_margin: voice_outbound_margin, quantity: @outgoing_duration,
                              selling_price: @outgoing_cost, selling_price_unit: 'USD', selling_price_eur: (@outgoing_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'sms_inbound', phone_type: '', cost_price: @sms_inbound_twilio_cost.abs, cost_price_unit: 'USD',
                              profit_margin: sms_inbound_margin, quantity: @sms_inbound_segments,
                              selling_price: @sms_inbound_cost, selling_price_unit: 'USD', selling_price_eur: (@sms_inbound_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'sms_outbound', phone_type: '', cost_price: @sms_outbound_twilio_cost.abs, cost_price_unit: 'USD',
                              profit_margin: sms_outbound_margin, quantity: @sms_outbound_segments,
                              selling_price: @sms_outbound_cost, selling_price_unit: 'USD', selling_price_eur: (@sms_outbound_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'phone', phone_type: 'local', cost_price: (@phone_local_twilio_cost * @phone_local_nums).ceil(2),
                              cost_price_unit: 'USD', profit_margin: phone_local_margin, quantity: @phone_local_nums,
                              selling_price: @phone_local_cost, selling_price_unit: 'USD', selling_price_eur: (@phone_local_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'phone', phone_type: 'mobile', cost_price: (@phone_mobile_twilio_cost * @phone_mobile_nums).ceil(2),
                              cost_price_unit: 'USD', profit_margin: phone_mobile_margin, quantity: @phone_mobile_nums,
                              selling_price: @phone_mobile_cost, selling_price_unit: 'USD', selling_price_eur: (@phone_mobile_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'phone', phone_type: 'national', cost_price: (@phone_national_twilio_cost * @phone_national_nums).ceil(2),
                              cost_price_unit: 'USD', profit_margin: phone_national_margin, quantity: @phone_national_nums,
                              selling_price: @phone_national_cost, selling_price_unit: 'USD', selling_price_eur: (@phone_national_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'sip', phone_type: '', cost_price: @sip_twilio_cost,
                              cost_price_unit: 'USD', profit_margin: sip_margin, quantity: 0,
                              selling_price: @sip_cost, selling_price_unit: 'USD', selling_price_eur: (@sip_cost * euro_rate).ceil(2))
        billing.save
        billing = Billing.new(client_id: client.id, ivr_id: ivr.id, category: 'seat', phone_type: (client.organizations.first && client.organizations.first.chargebee_subscription_plan ? client.organizations.first.chargebee_subscription_plan : '') + '-' + (client.organizations.first && client.organizations.first.chargebee_subscription_period ? client.organizations.first.chargebee_subscription_period : ''),
                              cost_price: 0, cost_price_unit: '', profit_margin: 0, quantity: @seat_nums,
                              selling_price: @seat_cost, selling_price_unit: 'USD', selling_price_eur: (@seat_cost * euro_rate).ceil(2))
        billing.save
      end
    end

  end

end

