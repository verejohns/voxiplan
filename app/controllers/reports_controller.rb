class ReportsController < ApplicationController
  include ApplicationHelper
  include ReportHelper

  before_action :check_ory_session
  layout 'layout'
  require 'money/bank/uphold'

  def index
  end
  def aggregates
    redirect_to request.env["HTTP_REFERER"] and return unless checkRelationTuple("/organization-" + session[:current_organization].id.to_s + "/billing", "manage", "client-" + current_client.id.to_s)

    # start_date = Time.now - 1.month
    # BillingJob.perform_now(start_date.to_s, 'add_usage_telecom')

    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    result = ChargeBee::Subscription.retrieve(session[:current_organization].chargebee_subscription_id)
    subscription = result.subscription

    @subscription_seats = 1
    @subscription_period = subscription.billing_period_unit + 'ly'
    if subscription.subscription_items.count.zero?
      @subscription_plan = 'free'
    else
      subscription.subscription_items.each do |subscription_item|
        @subscription_plan = ''
        @subscription_plan = 'free' if subscription_item.item_price_id == ENV['FREE_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['FREE_MONTHLY_EUR_ID']
        @subscription_plan = 'basic' if subscription_item.item_price_id == ENV['BASIC_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['BASIC_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['BASIC_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['BASIC_YEARLY_EUR_ID']
        @subscription_plan = 'premium' if subscription_item.item_price_id == ENV['PREMIUM_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['PREMIUM_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['PREMIUM_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['PREMIUM_YEARLY_EUR_ID']
        @subscription_plan = 'custom' if subscription_item.item_price_id == ENV['CUSTOM_MONTHLY_USD_ID'] || subscription_item.item_price_id == ENV['CUSTOM_MONTHLY_EUR_ID'] || subscription_item.item_price_id == ENV['CUSTOM_YEARLY_USD_ID'] || subscription_item.item_price_id == ENV['CUSTOM_YEARLY_EUR_ID']
        @subscription_seats = subscription_item.quantity and break unless @subscription_plan.blank?
      end
    end

    @subscription_status = subscription.status
    unless @subscription_status == "cancelled"
      current_client.organizations.update_all(chargebee_subscription_plan: @subscription_plan)
      session[:current_organization] = current_client.organizations.first
    end

    redirect_to billing_client_path(current_client.id) and return if @subscription_plan == "free" || @subscription_plan == "trial"

    @year = params[:year] || Date.today.year
    @month = params[:month].present? ? Date::MONTHNAMES[params[:month].to_i] : Date::MONTHNAMES[Date.today.month]
    @currency_code = session[:currency_symbol]

    @billing_data = []
    prev_ivr = 0
    if params[:year].to_i > Date.today.year || (params[:year].to_i == Date.today.year && params[:month].to_i > Date.today.month)
      @billing_data = nil
    else
      month =  params[:month] || Date.today.month
      begin_of_month = Time.parse(@year.to_s + '-' + month.to_s + '-01') + 1.month
      end_of_month = Time.parse(begin_of_month.to_s).end_of_month

      @seat_nums = 0
      @seat_cost = 0
      @task_count = 0
      @task_cost = 0
      @appointments = 0
      @appointments_cost = 0
      @incoming_local_duration = 0
      @incoming_local_cost = 0
      @incoming_mobile_duration = 0
      @incoming_mobile_cost = 0
      @outgoing_duration = 0
      @outgoing_cost = 0
      @sms_inbound_segments = 0
      @sms_inbound_cost = 0
      @sms_outbound_segments = 0
      @sms_outbound_cost = 0
      @phone_local_nums = 0
      @phone_local_cost = 0
      @phone_mobile_nums = 0
      @phone_mobile_cost = 0
      @phone_national_nums = 0
      @phone_national_cost = 0
      @sip_cost = 0
      @ivr_name = ''

      @all_account_cost = 0
      @billings = Billing.where('client_id=? AND created_at BETWEEN ? AND ?', current_client.id, begin_of_month, end_of_month.strftime('%Y-%m-%d %H:%M:%S')).order(:client_id, :ivr_id)
      @billings.each do |billing|
        if prev_ivr != billing.ivr_id
          unless prev_ivr.zero?
            ivr = Ivr.find(prev_ivr)
            @voice_incoming_cost = @incoming_local_cost + @incoming_mobile_cost
            @voice_cost = @voice_incoming_cost + @outgoing_cost
            @sms_cost = @sms_inbound_cost + @sms_outbound_cost
            @message_cost = @sms_cost
            @phone_cost = @phone_local_cost + @phone_mobile_cost + @phone_national_cost
            @telecom_cost = @voice_cost + @message_cost + @phone_cost + @sip_cost
            @account_cost = @task_cost + @appointments_cost + @telecom_cost + @seat_cost
            @all_account_cost += @account_cost
            @billing_data.push({ivr_name: ivr.name, task_count: @task_count, task_cost: @task_cost, appointments: @appointments, appointments_cost: @appointments_cost,
                               voice_incoming_cost: @voice_incoming_cost, voice_cost: @voice_cost, account_cost: @account_cost,
                               sms_cost: @sms_cost, message_cost: @message_cost, phone_cost: @phone_cost, telecom_cost: @telecom_cost,
                               incoming_local_duration: @incoming_local_duration, incoming_local_cost: @incoming_local_cost,
                               incoming_mobile_duration: @incoming_mobile_duration, incoming_mobile_cost: @incoming_mobile_cost,
                               outgoing_duration: @outgoing_duration, outgoing_cost: @outgoing_cost,
                               sms_inbound_segments: @sms_inbound_segments, sms_inbound_cost: @sms_inbound_cost,
                               sms_outbound_segments: @sms_outbound_segments, sms_outbound_cost: @sms_outbound_cost,
                               phone_local_nums: @phone_local_nums, phone_local_cost: @phone_local_cost,
                               phone_mobile_nums: @phone_mobile_nums, phone_mobile_cost: @phone_mobile_cost,
                               phone_national_nums: @phone_national_nums, phone_national_cost: @phone_national_cost, sip_cost: @sip_cost,
                               seats: @seat_nums, seats_cost: @seat_cost})
          end

          @seat_nums = 0
          @seat_cost = 0
          @task_count = 0
          @task_cost = 0
          @appointments = 0
          @appointments_cost = 0
          @incoming_local_duration = 0
          @incoming_local_cost = 0
          @incoming_mobile_duration = 0
          @incoming_mobile_cost = 0
          @outgoing_duration = 0
          @outgoing_cost = 0
          @sms_inbound_segments = 0
          @sms_inbound_cost = 0
          @sms_outbound_segments = 0
          @sms_outbound_cost = 0
          @phone_local_nums = 0
          @phone_local_cost = 0
          @phone_mobile_nums = 0
          @phone_mobile_cost = 0
          @phone_national_nums = 0
          @phone_national_cost = 0
          @sip_cost = 0
        end


        if billing.category == 'seat'
          @seat_nums = billing.quantity
          @seat_cost = billing.selling_price
        end

        if billing.category == 'task'
          @task_count = billing.quantity
          @task_cost = billing.selling_price
        end

        if billing.category == 'appointment'
          @appointments = billing.quantity
          @appointments_cost = billing.selling_price
        end

        if billing.category == 'voice_inbound' && billing.phone_type == 'local'
          @incoming_local_duration = billing.quantity
          @incoming_local_cost = billing.selling_price
        end

        if billing.category == 'voice_inbound' && billing.phone_type == 'mobile'
          @incoming_local_duration = billing.quantity
          @incoming_local_cost = billing.selling_price
        end

        if billing.category == 'voice_outbound'
          @outgoing_duration = billing.quantity
          @outgoing_cost = billing.selling_price
        end

        if billing.category == 'sms_inbound'
          @sms_inbound_segments = billing.quantity
          @sms_inbound_cost = billing.selling_price
        end

        if billing.category == 'sms_outbound'
          @sms_outbound_segments = billing.quantity
          @sms_outbound_cost = billing.selling_price
        end

        if billing.category == 'phone' && billing.phone_type == 'local'
          @phone_local_nums = billing.quantity
          @phone_local_cost = billing.selling_price
        end

        if billing.category == 'phone' && billing.phone_type == 'mobile'
          @phone_mobile_nums = billing.quantity
          @phone_mobile_cost = billing.selling_price
        end

        if billing.category == 'phone' && billing.phone_type == 'national'
          @phone_national_nums = billing.quantity
          @phone_national_cost = billing.selling_price
        end

        if billing.category == 'sip'
          @sip_cost = billing.selling_price
        end

        prev_ivr = billing.ivr_id
      end
    end

    unless @billing_data.nil? || prev_ivr.zero?
      ivr = Ivr.find(prev_ivr)
      @voice_incoming_cost = @incoming_local_cost + @incoming_mobile_cost
      @voice_cost = @voice_incoming_cost + @outgoing_cost
      @sms_cost = @sms_inbound_cost + @sms_outbound_cost
      @message_cost = @sms_cost
      @phone_cost = @phone_local_cost + @phone_mobile_cost + @phone_national_cost
      @telecom_cost = @voice_cost + @message_cost + @phone_cost + @sip_cost
      @account_cost = @task_cost + @appointments_cost + @telecom_cost + @seat_cost
      @all_account_cost += @account_cost

      @billing_data.push({ivr_name: ivr.name, task_count: @task_count, task_cost: @task_cost, appointments: @appointments, appointments_cost: @appointments_cost,
                          voice_incoming_cost: @voice_incoming_cost, voice_cost: @voice_cost, account_cost: @account_cost,
                          sms_cost: @sms_cost, message_cost: @message_cost, phone_cost: @phone_cost, telecom_cost: @telecom_cost,
                          incoming_local_duration: @incoming_local_duration, incoming_local_cost: @incoming_local_cost,
                          incoming_mobile_duration: @incoming_mobile_duration, incoming_mobile_cost: @incoming_mobile_cost,
                          outgoing_duration: @outgoing_duration, outgoing_cost: @outgoing_cost,
                          sms_inbound_segments: @sms_inbound_segments, sms_inbound_cost: @sms_inbound_cost,
                          sms_outbound_segments: @sms_outbound_segments, sms_outbound_cost: @sms_outbound_cost,
                          phone_local_nums: @phone_local_nums, phone_local_cost: @phone_local_cost,
                          phone_mobile_nums: @phone_mobile_nums, phone_mobile_cost: @phone_mobile_cost,
                          phone_national_nums: @phone_national_nums, phone_national_cost: @phone_national_cost, sip_cost: @sip_cost,
                          seats: @seat_nums, seats_cost: @seat_cost})
    end
  end

  def create_portal_session
    customer_id = session[:current_organization].id
    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    result = ChargeBee::PortalSession.create({ :customer => { :id => customer_id }, :redirect_url => aggregates_reports_url })
    render :json => result.portal_session.to_s
  rescue => e
    render :json => { error_message: e.message }
  end

  def logout_portal_session
    ChargeBee.configure(:site => ENV['CHARGEBEE_SITE'], :api_key => ENV['CHARGEBEE_SITE_APIKEY'])
    ChargeBee::PortalSession.logout(params[:portal_session_id])
    render :json => ''
  end

  def calls
    @calls_data = []
    @incoming_nums = 0
    @outgoing_nums = 0
    black_lists = []

    current_client.ivrs.each do |ivr|
      black_list = ivr.find_node('check_caller_id').right_operand
      black_list.each do |black_data|
        black_lists.push(black_data)
      end

      from_date = params[:from_date] || ''
      from_date += ' 00:00:00' if from_date.present?
      to_date = params[:to_date] || ''
      to_date += ' 23:59:59' if to_date.present?

      calls = (from_date.blank? && to_date.blank?) ? ivr.calls : ivr.calls.where(:created_at =>from_date..to_date)

      stats = calls.stats
      @incoming_nums += stats[:incoming_call]
      @outgoing_nums += stats[:outgoing_call]

      locale_code = ivr.voice_locale + '-' + current_client.country_code rescue 'en'

      calls.each do |call|
        from = (Customer.where(id: Contact.where(phone: ('+' + call.from_parsed.gsub('+', ''))).map(&:customer_id), client_id: current_client.id).try(:first).try(:full_name) || '') + '@' + call.from_parsed
        from = call.from_parsed if from.delete(' ') == '@' + call.from_parsed
        from = 'unknown' if black_lists.include?(call.from_parsed)

        caller = Customer.where(id: Contact.where(phone: ('+'+call.entered_number.gsub('+',''))).map(&:customer_id), client_id: current_client.id).try(:first).try(:full_name) if call.entered_number
        caller = call.entered_number if caller == ' ' || caller.nil?
        caller = '-' unless call.entered_number

        status = '-'
        status = 'processed' if call.call_type == 'incoming'
        status = '-' if call.call_type == 'outgoing'
        status = 'not_completed' if call.call_type == 'missed'
        status = 'forwarded' if call.call_type == 'forwarded'

        call_data = {
          'Date' => [call.created_at.strftime('%Y-%m-%d %H:%M:%S'), locale_code],
          'Duration' => Time.at(call.get_incoming_duration).gmtime.strftime("%M Min %S Seconds"),
          'From' => from,
          'Caller' => caller,
          'ContactType' => call.client_type ? call.client_type == 'new' ? t('call_stats.new') : call.client_type.try(:camelize) : t('call_stats.undefined'),
          'Direction' => call.call_type == 'outgoing' ? 'outgoing' : 'incoming',
          'Status' => status,
          'CallForAppointment' => call.call_for_appointment ? 'yes' : 'no',
          'NumberOfRecordings' => call.recordings_count,
          'AppointmentStatus' => call.appointment_type.present? ? call.appointment_type : call.call_for_appointment ? ('Unknown') : "-",
          'NumberOfSMS' => call.text_messages_count,
          'To' => call.to_parsed,
        }
        @calls_data.push(call_data)
      end
    end

    # puts @calls_data
  end

  def sms_list
    @sms_data = []
    @incoming_nums = 0
    @outgoing_nums = 0
    black_lists = []

    current_client.ivrs.each do |ivr|
      from_date = params[:from_date] || ''
      from_date += ' 00:00:00' if from_date.present?
      to_date = params[:to_date] || ''
      to_date += ' 23:59:59' if to_date.present?

      msgs = (from_date.blank? && to_date.blank?) ? ivr.text_messages.includes(:call) : ivr.text_messages.includes(:call).where(:created_at =>from_date..to_date)

      stats = msgs.stats
      @incoming_nums += stats[:incoming_sms]
      @outgoing_nums += stats[:outgoing_sms]

      locale_code = ivr.voice_locale + '-' + current_client.country_code rescue 'en'

      msgs.each do |msg|
        to = Customer.where(id: Contact.where(phone: ('+' + msg.to.gsub('+', ''))).map(&:customer_id), client_id: current_client.id).try(:first).try(:full_name)
        to = msg.to if to == ' '

        from = Customer.where(id: Contact.where(phone: ('+' + msg.from.gsub('+',''))).map(&:customer_id), client_id: current_client.id).try(:first).try(:full_name)
        from = msg.from if from == ' '

        msg_data = {
          'Date' => [msg.created_at.strftime('%Y-%m-%d %H:%M:%S'), locale_code],
          'To' => to,
          'From' => from,
          'Status' => msg.incoming ? 'incoming' : 'outgoing',
          'Message' => msg.content || '-',
          'DeliveryReport' => msg.twilio_status ? msg.twilio_status.camelize : case msg.status when 9 then 'delivered' when -1 then 'sent' when 10 then 'delivery_failed' when 1,2,3,4 then 'send_failed' when nil then '-' else '' end
        }
        @sms_data.push(msg_data)
      end
    end
  end

  def url
    @url_data = []
    current_client.ivrs.each do |ivr|
      msg_ids = TextMessage.where(call: ivr.calls).pluck(:id)
      urls = Shortener::ShortenedUrl.where(owner_id: msg_ids)
      urls.each do |url|
        url_data = {
          'ShortURL' => url.short_url,
          'TargetURL' => url.url,
          'SentOn' => url.created_at,
          'Clicks' => url.use_count,
          'LastClickedAt' => url.created_at, # url.analytics.last&.created_at,
          'ContactName' => short_url_customer(url)&.full_name,
          'ContactNumber' => short_url_customer(url).try(:phone)&.prepend('+') || url.owner.to,
        }
        @url_data.push(url_data)
      end
    end
  end

end
