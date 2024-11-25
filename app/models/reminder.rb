class Reminder < ApplicationRecord
  belongs_to :ivr
  belongs_to :client
end
