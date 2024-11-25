class Analytic < ApplicationRecord
  belongs_to :analysable, polymorphic: true
end