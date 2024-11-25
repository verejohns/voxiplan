class GenerateTranscriptionJob < ApplicationJob
  queue_as :default

  def perform(recording_id)
    recording = Recording.find recording_id
    return unless recording.url && recording.transcription.nil?
    recording.update transcription: GoogleSpeechToText.recognise(recording.url, recording.google_voice_locale)
  end
end
