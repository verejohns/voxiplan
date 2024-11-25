class Service < ApplicationRecord
  belongs_to :ivr
  belongs_to :client
  has_many :resource_services, dependent: :destroy
  has_many :resources, through: :resource_services
  has_many :ivr_services, class_name: 'Service', foreign_key: 'service_id'
  has_many :questions, dependent: :destroy
  has_many :appointments, dependent: :destroy
  has_many :service_notifications, dependent: :destroy
  has_one :reminder, dependent: :destroy
  scope :active, -> { where(enabled: true) }
  scope :not_local, -> { where(is_local: nil) } # TODO: remove
  scope :for_widget, -> { where(eid: nil) } # TODO: Remove
  scope :for_client, ->(client_id) { where(client_id: client_id) }
  scope :ordered, -> { order("order_id ASC") }
  validates :name, presence: true,
  	:if => lambda { |invoice| invoice.is_local }

  def self.update_ordering(ordered_ids)
    rows = []
    ordered_ids.each_with_index do |id, i|
      rows << "(#{id}, #{i+1})"
    end
    self.connection
        .execute(update_order_query(rows.join(',')))
    true
  rescue StandardError => e
    puts "***************** Error : #{e.message}"
    false
  end

  def phone_service
    phone_services = Service.where(ivr_id: self.ivr_id, eid: self.id, agenda_type: 'ClassicAgenda')
    phone_services.count.zero? ? nil : phone_services.first
  end

  def title
    name.presence || ename
  end

  before_create :set_order

  def set_order
    return if order_id.present?

    scope = ivr || client
    self.order_id = (scope.services.maximum(:order_id) || 0) + 1
  end

  def availability=(availability)
    super(JSON.parse(availability))
  end

  private

  def self.update_order_query(rows)
    <<-SQL
      update services as s
      set
      order_id = updates.order_id
      from (values
        #{rows}
      ) as updates(id, order_id)
      where updates.id = s.id;
    SQL
  end
end
