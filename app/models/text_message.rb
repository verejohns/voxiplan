class TextMessage < ApplicationRecord
  belongs_to :ivr
  belongs_to :call, counter_cache: true, optional: true
  belongs_to :conversation, optional: true
  include UuidEntity
  has_shortened_urls

  validates :to, presence: true
  validates :from, presence: true, if: :incoming?

  before_create do
    to.strip!
    to.prepend('+') unless to.start_with?('+')
  end

  before_create :set_from
  before_create :set_conversation

  after_create :shorten_urls
  after_create :send_reply, if: :incoming?

  attr_accessor :session_id

  validate :mobile_number

  scope :incoming, -> { where(incoming: true) }
  scope :outgoing, -> { where(incoming: [false, nil]) }

  private

  def mobile_number
    # Phonelib.parse('+14152126060').types # => [:fixed_or_mobile]
    errors.add(:to, "is not a valid mobile number") unless (Phonelib.parse(to).types & %i[mobile fixed_or_mobile]).any?
  end

  def shorten_urls
    return unless shorten_urls_enabled?

    host = +(ENV["SHORT_URL_HOST"] || ENV['DOMAIN'])
    host.concat('/') unless host[-1] == '/'
    urls = UrlExtractor.extract_urls_with_indices(content)
    if urls.present?

      # if URL is at end of string and there is a one character(i-e dot) right after after URL
      # then remove last character, it will change 'visit example.com.' to 'visit example.com'
      urls.last[:indices][1] == self.content.length - 1
      self.content.chomp!(content[-1])

      urls.each do |hash|
        url = hash[:url]
        http_url = url.starts_with?('http') ? url : "http://#{url}"
        short_url = Shortener::ShortenedUrl.generate(http_url, owner: self)
        short_url.update(short_url: host + short_url.unique_key) if short_url
        self.content.gsub!(url, short_url.short_url) if short_url
      end

      self.save
    end
  end

  def shorten_urls_enabled?
    ivr&.preference.try(:[], 'shorten_urls')
  end

  def set_conversation
    # TODO: Handle 4 hours sessions
    self.conversation = Conversation.between(self.from, self.to).first.presence ||
      Conversation.create(
        to: self.to, from: self.from,
        ivr: self&.call&.ivr, session_id: session_id,
        client: self&.call&.ivr&.client
      )
  end

  def set_from
    self.from ||= ivr&.sms_number
  end

  def send_reply
    puts "****** created sms iwth id : #{self.id}"
    IncomingSmsReplyJob.set(wait: 5.seconds).perform_later(self.id)
  end

  def self.stats
    {
        incoming_sms: incoming.size,
        outgoing_sms: outgoing.size,
        total: all.size
    }
  end

end

