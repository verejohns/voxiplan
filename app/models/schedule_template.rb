class ScheduleTemplate < ApplicationRecord
  has_one :availability, dependent: :destroy
end
