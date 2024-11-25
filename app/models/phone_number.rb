class PhoneNumber < ApplicationRecord
  belongs_to :client

  before_validation :set_phone_attributes

  before_destroy do
    # TODO: Make sure to delete on communications platform i-e Twilio
  end

  scope :sms_enabled, -> { where(sms: true) }
  scope :voice_enabled, -> { where(voice: true) }

  validates :number, uniqueness: true

  private

  def set_phone_attributes
    phone = Phonelib.parse(self.number)
    self.number = phone.e164
    self.friendly_name ||= phone.national
    self.phone_type ||=
      case phone.type
      when :mobile
        'Mobile'
      when :fixed_line
        'Local'
      end
  end
end
