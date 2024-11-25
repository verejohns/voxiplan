module Authorization

  extend ActiveSupport::Concern

  included do
    before_action :authorize!
  end

  private

  def api_key
    request.headers['X-Voxiplan-API-Key'] || request.env['X-Voxiplan-API-Key']
  end

  def authorize!
    return true if ENV['VOXIPLAN_API_KEY'] == api_key
    raise AuthorizationError, 'Unauthorized'
  end

end
