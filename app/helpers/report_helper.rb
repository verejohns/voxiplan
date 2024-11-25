module ReportHelper

  def short_url_customer(short_url)
    number = short_url.owner.to.sub('+', '')
    @customer ||= current_client.customers.find_by(phone_number: number)
  end
end
