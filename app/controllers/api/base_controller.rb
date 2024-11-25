module Api
  INTERNAL_ERROR = 'INTERNAL_ERROR'
  UNAUTHORIZED_ERROR = 'UNAUTHORIZED_ERROR'
  ACCOUNT_ERROR = 'ACCOUNT_ERROR'

  class BaseController < ActionController::API
    include ErrorHandling
    include Authorization
    include FullLogging
    include Skylight::Helpers

    around_action :load_session_and_set_time_zone

    helper_method :current_ivr
    helper_method :current_call
    helper_method :current_client

    def current_ivr
      return @cur_ivr if @cur_ivr
      @cur_ivr = identifier.try(:ivr)
      raise AccountError, 'Account not found. Make sure to provide a valid identifier or sender' unless @cur_ivr
      @cur_ivr
    end

    def current_call
      Call.find(session[:data][:current_call_id]) if session[:data].try(:[], :current_call_id)
    end

    def current_client
      current_ivr.client
    end

    def current_voxi_session
      VoxiSession.find(session[:data][:current_voxi_session_id]) if session[:data].try(:[], :current_voxi_session_id)
    end

    def agenda_app
      current_client.agenda_apps
    end

    def data
      session[:data]
    end


    private

    def load_session_and_set_time_zone
      load_session
      Time.use_zone(current_ivr.client.time_zone) {yield}
    end

    # called from arond
    def load_session
      id = request.headers['X-Voxiplan-Session-ID'] || request.env['X-Voxiplan-Session-ID']
      # request.session_options[:id] = id.split('-').last  if id.present?

      platform = params[:platform] || 'api'
      phone = params[:user] ? params[:user][:phone] || '266696687' : '266696687'
      voxi_session = VoxiSession.find_by_session_id(id.split('-').last) if id
      ivr = Ivr.find(voxi_session.ivr_id) if voxi_session

      if params[:service_name]
        service = ivr.client.services.active.where("ivr_id=? AND lower(name) = ?", ivr.id, params[:service_name].downcase)&.first
        service = ivr.client.services.active.where("ivr_id=? AND lower(ename) = ?", ivr.id, params[:service_name].downcase)&.first unless service
        params[:service_id] = service.id
      end

      if params[:resource_name]
        resource = ivr.client.resources.active.where("ivr_id=? AND lower(name) = ?", ivr.id, params[:resource_name].downcase)&.first
        resource = ivr.client.resources.active.where("ivr_id=? AND lower(ename) = ?", ivr.id, params[:resource_name].downcase)&.first unless resource
        params[:resource_id] = resource.id
      end

      session[:data] = ivr.session_variables(phone: phone, platform: platform, session_id: id.split('-').last, maintain: true, service_id: params[:service_id], resource_id: params[:resource_id]) if ivr

      session[:data][:hints] = ''

      puts "~~~~~~~~~~~~~~~~ session data ~~~~~~~~~~~~~~~~~"
      puts session[:data]

      @cur_ivr = Ivr.find session[:data][:current_ivr_id]
      # incorporate current_call.data (updated in background)
      session[:data].merge!(current_call&.data.to_h.symbolize_keys) # TODO: DELETE, using VoxiSession now
      session[:data].merge!(current_voxi_session&.data.to_h.symbolize_keys)
    end

  end
end
