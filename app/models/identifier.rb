class Identifier < ApplicationRecord
  belongs_to :ivr
  validates :identifier, presence: true
  validates_uniqueness_of :identifier
  has_paper_trail

  after_save :create_phone_number

  private

  def create_phone_number
    return unless identifier.scan(/\D/).empty?

    twilioclient = Twilio::REST::Client.new(ENV['ACCOUNT_SID'], ENV['AUTH_TOKEN'])
    ipn = twilioclient.incoming_phone_numbers.list(phone_number: identifier)
    begin
      voice_capable = ipn.first.capabilities['voice']
    rescue
      voice_capable = true
    end
    begin
      sms_capable = ipn.first.capabilities['sms']
    rescue
      sms_capable = false
    end
    PhoneNumber.find_or_create_by(number: identifier, voice: voice_capable, sms: sms_capable)
  end
end
