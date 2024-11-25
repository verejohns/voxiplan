# TODO: Delete. Appointments are now associated to calls instead of client
class Appointment < ApplicationRecord
  # unknown = nil
  APPOINTMENT_TYPE = %w[new modified cancelled unknown].freeze
  belongs_to :client
  belongs_to :ivr
  belongs_to :resource, optional: true
  belongs_to :service, optional: true
  has_many :answers, dependent: :destroy

  scope :between, ->(start_date, end_date) {where("created_at > ? AND created_at < ?", start_date, end_date)}

end
