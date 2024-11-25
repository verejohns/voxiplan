module UidEntity
  extend ::ActiveSupport::Concern

  class_methods do
    UID_PREFIX = '999'
    UID_LENGTH = 10
    UID_MAX_TRIES = 20
  end

  included do
    before_create do
      min = '1' + '0' * (UID_LENGTH - UID_PREFIX.size - 1)
      max = '9' * (UID_LENGTH - UID_PREFIX.size)
      range = (min.to_i)..(max.to_i)
      tries = 0

      loop do
        tries += 1
        self.uid = UID_PREFIX + SecureRandom.random_number(range).to_s
        break unless self.class.exists?(uid: self.uid) && tries < UID_MAX_TRIES
      end

      self.uid = SecureRandom.hex if tries >= UID_MAX_TRIES
    end

  end
end
