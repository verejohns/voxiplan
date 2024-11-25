require 'shortener'
Shortener::ShortenedUrl.class_eval do
  has_many :analytics, as: :analysable
end  