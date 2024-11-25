class Question < ApplicationRecord
    belongs_to :service
    has_many :question_options, dependent: :destroy
    scope :active, -> { where(enabled: true) }
end