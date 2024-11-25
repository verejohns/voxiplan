class HttPartyJob < ApplicationJob
  queue_as :default

  def perform(method, url, params)
    puts "Gooing to call API, URL: #{url}"
    puts "method: #{method}, params: #{params}"
    puts "*********** end email **** "

    begin
      response = HTTParty.send(method, url, params)
    rescue Exception => e
      logger.error "XXXXXX Exception while calling API."
      puts e.message
      puts e.backtrace
    end

    puts "=== API CAll response.status_code: #{response.inspect}"
  end
end
