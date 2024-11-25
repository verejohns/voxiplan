class Contact < ApplicationRecord
  belongs_to :customer
  belongs_to :client
  before_save :set_phone_to_e164

  def set_phone_to_e164
    self.phone = parsed_phone.e164
    self.country ||= parsed_phone.country
  end

  def parsed_phone
    @parsed_phone ||= Phonelib.parse(self.phone, self.country)
  end

  validates :phone, uniqueness: { scope: :client_id }
  validate :has_valid_phone_number

  # enum phone_type: {mobile: 'mobile', fixed_line: 'fixed_line'}
  #
  private
  # def set_client
  #   self.client ||= customer.client
  # end
  #
  def has_valid_phone_number
    @parsed_phone = Phonelib.parse(phone)

    if @parsed_phone.valid?
      puts "****** phone #{phone} is valid for international format for #{@parsed_phone.country}"
    elsif Phonelib.valid_for_country? phone, client.country_code
      @parsed_phone = Phonelib.parse phone, client.country_code
      puts "****** phone #{phone} is valid for #{client.country_code} "
    else
      puts "****** phone #{@parsed_phone} is NOT valid for #{client.country_code} "
      errors.add(:@parsed_phone, "Not a valid international or local #{client.country}")
    end
  end
end
