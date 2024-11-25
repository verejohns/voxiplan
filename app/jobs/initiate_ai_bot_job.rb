class InitiateAiBotJob < ApplicationJob
  queue_as :default

  def perform(agenda_app_id, current_call_id, locale, data, assistant_name, language, timezone, platform)
    logger.info "XXXX STARTED JOB: InitiateAiBotJob."
    begin
      # Use only if different Rasa server for each language
      # response = RasaParty.new(data[:session_id], locale).chat(message: '/ping')
      response = RasaParty.new(data[:session_id], assistant_name, language, timezone, locale, platform).chat(message: '/ping')
      logger.info "XXXX JOB: InitiateAiBotJob. Bot response: #{response.inspect}"
    rescue Exception => e
      logger.error "XXXXXX Exception while InitiateAiBotJob."
      puts e.message
      puts e.backtrace
    end
  end
end
