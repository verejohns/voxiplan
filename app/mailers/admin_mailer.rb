class AdminMailer < ApplicationMailer
  default :from => 'contact@voxiplan.com',
          :reply_to => 'contact@voxiplan.com'

  def new_number_request_to_admin(account, params)
    options = {:to=>ENV['PHONE_ADMIN'], :body=>"testing 123", subject: t('services.new_number_request_title')}
    @account = account
    @client = account.client
    @number = params[:number]

    if params[:phone_individual] == 'true'
      @phone_user = 'individual'
      @phone_user_label = t('services.review_phone_number.individual')
      @individual_first_name = params[:individual_first_name]
      @individual_last_name = params[:individual_last_name]
    end

    if params[:phone_business] == 'true'
      @phone_user = 'business'
      @phone_user_label = t('services.review_phone_number.business')
      @business_name = params[:business_name]
      @business_number = params[:business_number]
      @business_first_name = params[:business_first_name]
      @business_last_name = params[:business_last_name]
      @business_address = params[:business_address]
    end

    mail(:to => options[:to], :subject => options[:subject])
  end

  def new_number_request_to_client(account)
    @account = account
    @client = account.client

    headers "X-SMTPAPI" => {
      "sub": { "%name%" => [@client.email] },
      "filters": { "templates": { "settings": { "enable": 1, "template_id": "30be717a-4459-473b-af61-1660b51c4ffe" } } }
    }.to_json

    mail(:to => @client.email, :subject => t('services.new_number_requested_title'))
  end
end
