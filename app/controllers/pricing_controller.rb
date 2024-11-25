class PricingController < ApplicationController
	include ApplicationHelper
  layout 'layout_noneed_login'
  require 'money/bank/uphold'

  def index
    @exchng_rate = case params[:u] when 'eur' then 1 when 'usd' then fetch_eur_rate else 1 end
    @currency_code = case params[:u] when 'eur' then '€' when 'usd' then '$' else '€' end
    user_country = fetch_user_country(current_client)

    pricing_details = YAML.load(File.read(File.expand_path('db/pricing_details.yml')))

    @appointment_pricing = pricing_details.symbolize_keys[:appointments]
    @agenda_pricing = pricing_details.symbolize_keys[:agenda_connection]
    @sip_pricing = pricing_details.symbolize_keys[:sip]
		voice_data = pricing_details.symbolize_keys[:voice]
    sms_data = pricing_details.symbolize_keys[:sms]
    phone_data = pricing_details.symbolize_keys[:phone_number]

		@appointment_margin = fetch_margin_val(@appointment_pricing[:margin].to_i)
		@agenda_margin = fetch_margin_val(@agenda_pricing[:margin].to_i)
		@sip_margin = fetch_margin_val(@sip_pricing[:margin].to_i)
		@voice_margin = fetch_margin_val(voice_data[:margin].to_i)
		@sms_margin = fetch_margin_val(sms_data[:margin].to_i)
		@phone_margin = fetch_margin_val(phone_data[:margin].to_i)

  	twilioclient = Twilio::REST::Client.new(ENV['ACCOUNT_SID'], ENV['AUTH_TOKEN'])
    countries = twilioclient.pricing.phone_numbers.countries.list
    corr_country = 0

    countries.each do |c|
      if user_country == c.iso_country
				corr_country = 1
			end
		end


		user_country = 'BE' if corr_country != 1
		@phone_pricing = twilioclient.pricing.v1.phone_numbers.countries(user_country).fetch
		@sms_pricing = twilioclient.pricing.v1.messaging.countries(user_country).fetch
		@voice_pricing = twilioclient.pricing.v2.voice.countries(user_country).fetch

		outbound_sms_prices = {}
		@sms_pricing.outbound_sms_prices.map do |details|
		details = details.with_indifferent_access
		details['prices'].map do |price_details|
		if outbound_sms_prices[price_details['number_type']].present? && outbound_sms_prices[price_details['number_type']].to_f > price_details['base_price'].to_f
			outbound_sms_prices[price_details['number_type']] = price_details['base_price'].to_f
		elsif !outbound_sms_prices[price_details['number_type']].present?
			outbound_sms_prices[price_details['number_type']] = price_details['base_price'].to_f
		end
		rescue Exception => e
			puts e
			end
		end

		inbound_sms_prices = {}
		@sms_pricing.inbound_sms_prices.map do |price_details|
			price_details = price_details.with_indifferent_access
			begin
			if inbound_sms_prices[price_details['number_type']].present? && inbound_sms_prices[price_details['number_type']].to_f > price_details['base_price'].to_f
				inbound_sms_prices[price_details['number_type']] = price_details['base_price'].to_f
			elsif !inbound_sms_prices[price_details['number_type']].present?
				inbound_sms_prices[price_details['number_type']] = price_details['base_price'].to_f
			end
			rescue Exception => ex
			puts ex.message
			end
		end

		sms_prices_keys = inbound_sms_prices.keys | outbound_sms_prices.keys
		@sms_prices = []
			sms_prices_keys.each do |price_key|
				@sms_prices << {  'price_type': price_key,
								 'inbound_price':  inbound_sms_prices[price_key] ? "#{@currency_code} #{(((inbound_sms_prices[price_key]*@exchng_rate).ceil(2))*@sms_margin).ceil(2)}/sms" : '',
										'outbound_price': outbound_sms_prices[price_key] ? "#{@currency_code} #{(((outbound_sms_prices[price_key]*@exchng_rate).ceil(2))*@sms_margin).ceil(2)}/sms" : ''
										 }
			end

			outbound_voice_prices = {}
			@voice_pricing.outbound_prefix_prices.map do |price_details|
			price_details = price_details.with_indifferent_access
			begin
				if outbound_voice_prices[price_details['friendly_name']].present? && outbound_voice_prices[price_details['friendly_name']].to_f > price_details['base_price'].to_f
				outbound_voice_prices[price_details['friendly_name']] = price_details['base_price'].to_f
			elsif !outbound_voice_prices[price_details['friendly_name']].present?
				outbound_voice_prices[price_details['friendly_name']] = price_details['base_price'].to_f
			end
			rescue Exception => ex
			puts ex.message
			end
		end

		inbound_voice_prices = {}
		@voice_pricing.inbound_call_prices.map do |price_details|
			price_details = price_details.with_indifferent_access
			begin
			if inbound_voice_prices[price_details['number_type']].present? && inbound_voice_prices[price_details['number_type']].to_f > price_details['base_price'].to_f
				inbound_voice_prices[price_details['number_type']] = price_details['base_price'].to_f
			elsif !inbound_voice_prices[price_details['number_type']].present?
				inbound_voice_prices[price_details['number_type']] = price_details['base_price'].to_f
			end
			rescue Exception => ex
			puts ex.message
			end
		end

    voice_prices_keys = inbound_voice_prices.keys | outbound_voice_prices.keys
    @voice_prices = []
    voice_prices_keys.each do |price_key|
      @voice_prices << {  'price_type': price_key.to_s.sub('Programmable Outbound Minute - ',''),
    	               'inbound_price':  inbound_voice_prices[price_key] ? "#{@currency_code} #{(((inbound_voice_prices[price_key]*@exchng_rate).ceil(2))*@voice_margin).ceil(2)}/min" : '',
    	              'outbound_price': outbound_voice_prices[price_key] ? "#{@currency_code} #{(((outbound_voice_prices[price_key]*@exchng_rate).ceil(2))*@voice_margin).ceil(2)}/min" : ''
    	               }
    end
		@usr_country = user_country
  end

 #  def pay_via_gocardless
 #  	client = GoCardlessPro::Client.new(
	# 	access_token: ENV['Gocardless_token'],
	# 	environment: :sandbox
	# )
	# redirect_flow = client.redirect_flows.create(
	#   params: {
	#     description: 'Lager Kegs', # This will be shown on the payment pages
	#     session_token: 'dummy_session_token', # Not the access token
	#     success_redirect_url: finalize_payment_pricing_index_url,
	#     prefilled_customer: { # Optionally, prefill customer details on the payment page
	#       given_name: 'Tim',
	#       family_name: 'Rogers',
	#       email: 'tim@gocardless.com',
	#       address_line1: '338-346 Goswell Road',
	#       city: 'London',
	#       postal_code: 'EC1V 7LQ'
	#     }
	#   }
	# )
	# redirect_to redirect_flow.redirect_url
 #  end

 #  def finalize_payment
	# client = GoCardlessPro::Client.new(
	# 	access_token: ENV['Gocardless_token'],
	# 	environment: :sandbox
	# )
	# redirect_flow = client.redirect_flows.complete(
 #    	params[:redirect_flow_id], # The redirect flow ID from above.
 #    	params: { session_token: 'dummy_session_token' })
	# payment = client.payments.create(
	# 			customer: redirect_flow.links.customer,
	# 			params: {
	# 				amount: 1000,
	# 				currency: "EUR",
	# 				description: "Voxiplan monthly payment",
	# 				links: {mandate: redirect_flow.links.mandate}
	# 			}
	# 		)
	# puts "ID: #{payment.id}"

	# @success_message = "Client successfuly verified through goCardless!"
 #  end

end
