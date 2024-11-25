module ErrorHandling

  extend ActiveSupport::Concern

  included do
    rescue_from StandardError, with: :respond_with_internal_error
    rescue_from AuthorizationError, with: :respond_with_unauthorized_error
    rescue_from AccountError, with: :respond_with_account_error
  end

  def respond_with_internal_error(error)
    log_error(error)
    render(
        json: { message: error.message, error_code: Api::INTERNAL_ERROR },
        status: :internal_server_error
    )
  end

  def respond_with_unauthorized_error(error)
    render(
        json: { message: error.message, error_code: Api::UNAUTHORIZED_ERROR },
        status: :unauthorized
    )
  end

  def respond_with_account_error(error)
    render(
        json: { message: error.message, error_code: Api::ACCOUNT_ERROR },
        status: :unauthorized
    )
  end

  def log_error(error)
    Rails.logger.fatal(error)
    Rails.logger.warn(error.backtrace.join("\n"))
  end

end