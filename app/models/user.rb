class User < ApplicationRecord
  # rolify
  include UidEntity
  include PhoneNumberUtils

  belongs_to :client
  before_create :create_sip
  before_save :set_phone_to_e164

  has_and_belongs_to_many :nodes

  # Role::ROLES.each do |role|
  #   define_method("is_#{role.first}?") do
  #     (self.roles.map(&:name).include? role.last) rescue false
  #   end
  # end

  def set_phone_to_e164
    self.number = valid_international_or_local(self.number, client.country)
  end

  def self.all_as_json client
    users = client.users
    users_data = users.map do |user|
      {
        "UserID": user.id,
        "Name": user.name,
        "Email": user.email,
        "Phone": user.number,
        "sip": user.sip,
        "isDefault": !!user.is_default
      }
    end

    return {
      "meta": {
          "page": 1,
          "pages": 1,
          "perpage": -1,
          "total": 50,
          "sort": "asc",
          "field": "RecordID"
      },
      "data": users_data
    }
  end

  def create_sip
    self.sip = "#{self.uid}@voxiplan.com"
  end

  def available?
    BusinessHours.within_biz_hours(self.availability)
  end

  # TODO: Delete. We don't need to transfer to sip, using numbers is also fine with Twilio
  # number + '@voxiplan.com'
  # def number_to_sip
  #   return unless self.number.present?
  #   "#{self.number}@voxiplan.com"
  # end
end