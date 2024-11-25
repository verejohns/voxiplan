class Conversation < ApplicationRecord
  belongs_to :client
  belongs_to :ivr
  has_many :text_messages, dependent: :destroy

  scope :involving, -> (phone) do
    where("conversations.from =? OR conversations.to =?", phone, phone)
  end

  scope :between, -> (from, to) do
    where("(conversations.from = ? AND conversations.to =?)
            OR
           (conversations.from = ? AND conversations.to =?)",
          from, to, to, from)
  end
end
