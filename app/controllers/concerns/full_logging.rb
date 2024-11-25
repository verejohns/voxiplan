module FullLogging

  extend ActiveSupport::Concern

  included do
    around_action :log_everything
  end

  private

  def log_everything
    log_headers
    yield
  ensure
    log_headers
    log_response
  end

  def log_headers
    http_envs = {}.tap do |envs|
      request.headers.each do |key, value|
        envs[key] = value if key.downcase.starts_with?('http')
      end
    end

    logger.info "\n\n<<<<Request:>>> Received #{request.method.inspect} #{request.url.inspect} \n>>>>params: #{params.inspect} \n>>>>Headers: #{http_envs.inspect}\n"
  end

  def log_response
    logger.info "\n<<<<Response:>> #{response.status.inspect} \n>>>>=> #{response.body}\n"
  end
end
