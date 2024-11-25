class Resource < ApplicationRecord
  belongs_to :ivr
  belongs_to :client
  has_many :resource_services, dependent: :destroy
  has_many :services, through: :resource_services
  has_many :ivr_resource, class_name: 'Resource', foreign_key: 'resource_id'
  has_many :appointments, dependent: :destroy
  scope :active, -> { where(enabled: true) }
  scope :not_local, -> { where(is_local: nil) } # TODO: Remove
  scope :for_widget, -> { where(eid: nil) } # TODO: Remove
  scope :for_client, ->(client_id) { where(client_id: client_id) }
  scope :ordered, -> { order("order_id ASC") }
  # scope :voxiplan, -> { where(enabled: true, is_local: true) }
  # scope :local, -> { where(agenda_type: ClassicAgenda.to_s)}
  validates :name, presence: true,
  	:if => lambda { |invoice| invoice.is_local }

  def title
    name.presence || ename
  end
end
