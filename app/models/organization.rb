class Organization < ApplicationRecord
  has_many :ivrs
  has_many :agenda_apps
end
