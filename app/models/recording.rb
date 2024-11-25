class Recording < ApplicationRecord
  belongs_to :call, counter_cache: true
  include UuidEntity

  # TODO: Use already generated transcription
  after_create :generate_transcription, if: Proc.new { self.url && self.transcription.nil? }

  def to_param
    self.uuid
  end

  def voxi_url
    Rails.application.routes.url_helpers.recording_url(self)
  end

  def locale
    self.call.try(:ivr).try(:voice_locale)
  end

  def google_voice_locale
    self.call.try(:ivr).try(:google_voice_locale)
  end

  private

  def generate_transcription
    GenerateTranscriptionJob.perform_later(self.id)
  end
end
