module UuidEntity
  extend ::ActiveSupport::Concern

  included do
    before_create do
      self.uuid = SecureRandom.hex
    end
  end
end
