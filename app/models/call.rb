class Call < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :ivr, optional: true
  has_many :tropo_webhooks, :foreign_key => :internal_call_id
  has_many :recordings, dependent: :destroy
  has_many :text_messages, dependent: :destroy
  has_many :analytics, as: :analysable
  has_many :voxi_sessions, dependent: :destroy

  after_initialize do
    self.call_type = 'incoming' unless self.call_type
  end

  before_save :set_billable_minutes

  serialize :data, Hash

  scope :has_appointments, -> { where.not(appointment_time: [nil]) }

  enum appointment_type: { new: 'new', cancelled: 'cancelled', modified: 'modified' }, _suffix: :appointment
  enum call_type: { incoming: 'incoming', missed: 'missed', forwarded: 'forwarded', outgoing: 'outgoing' }, _suffix: :call
  enum client_type: { new: 'new',  returning: 'returning' }, _suffix: :client

  # TODO: remove?
  has_attached_file :recording
  validates_attachment_content_type :recording, content_type: /audio/

  def call_for_appointment!
    update_column(:call_for_appointment, true)
  end

  def get_incoming_duration
    (((forwarded_at || finished_at) - created_at)).to_i rescue self.duration || 0
  end

  def save_data(key, value)
    data[key] = value
    self.save
  end

  def from_parsed
    transform_sip(from)
  end

  def to_parsed
    transform_sip(to)
  end

  private

  def set_billable_minutes
    seconds = get_incoming_duration
    return unless seconds

    self.minutes = (seconds / 60.0).ceil
  end

  def self.stats
    {
      incoming_call: all.size - outgoing_call.size,
      outgoing_call: outgoing_call.size,
      total: all.size
    }
  end

  def transform_sip(sip_number)
    phone_number = sip_number.match(/(?<=:)(.*)(?=@)/) if sip_number
    phone_number ? phone_number[0] : sip_number
  end
end
