class TimifyCredentialController < ApplicationController
  skip_before_action :verify_authenticity_token
  layout false

  def timify_cred
    t_token = (params[:accessToken] || cookies[:accessToken])
    @timify_webhook_record = WebhookCallDetail.find_by_access_token(t_token)
    if @timify_webhook_record
      if request.post?
        set_relative_data
        set_access_cookies
        @timify_email = @timify_webhook_record.email
        unless current_client.present?
          flash[:notice] = "Login with your voxiplan account"
          redirect_to ENV['ORY_URL'] + '/self-service/login/browser'
        end
      end
    else
      if current_client.present?
        sign_out(current_client)
      end
        flash[:notice] = "Login with your voxiplan account"
        redirect_to ENV['ORY_URL'] + '/self-service/login/browser'
    end
  end

  def new_account_cred
    raise "Bad Request!" unless request.post?
    params.require(:accessToken)
    params.require(:email)
    set_relative_data
    set_access_cookies
    sign_out(current_client) if current_client.present?
    redirect_to ENV['ORY_URL'] + '/self-service/registration/browser'
    rescue => e
      # sign_out(current_client) if current_client.present?
      flash[:notice] = e.message
      remove_cookies
      redirect_to root_path
  end

  def same_client
    set_default_agenda
    assign_webhook_access_data
    redirect_to agenda_app_path(connected: true)
  end

  def different_client
    sign_out(current_client)
    flash[:notice] = "Login with your voxiplan account"
    redirect_to ENV['ORY_URL'] + '/self-service/login/browser'
  end

  def cancel_process
    remove_cookies
    sign_out(current_client)
    flash[:notice] = "Process Cancelled"
    redirect_to ENV['ORY_URL'] + '/self-service/login/browser'
  end

  def check_timify_connection
    WebhookCallDetail.where(access_token: params[:"timify_token"]).present? ? is_present = WebhookCallDetail.where(access_token: params[:"timify_token"]).first.try(:client_id).present? : is_present = false
      render json: { is_present: is_present}
  end

  def disconnect_timify_connection
    if WebhookCallDetail.where(access_token: params[:"timify_token"]).present?
      WebhookCallDetail.where(access_token: params[:"timify_token"]).first.update(client_id: nil)
      AgendaApp.where(timify_access_token: params[:"timify_token"]).first.destroy
    end
  end

  private
  def set_relative_data
    @data = {
      processType: "AgendaApp",
      accessToken: params[:accessToken],
      email: params[:email]
      }
  end

  def set_access_cookies
    cookies[:processType] = { :value => @data[:processType], :expires => 3.minute.from_now}
    cookies[:accessToken] = { :value => @data[:accessToken], :expires => 3.minute.from_now}
    cookies[:email] = { :value => @data[:email], :expires => 3.minute.from_now}
  end

  def assign_webhook_access_data
    remove_cookies
    if @webhook_data.present?
      WebhookCallDetail.where(client_id: current_client.id).update_all(client_id: nil)
      @webhook_data.update(client: current_client)
    end
  end

  def remove_cookies
    cookies.delete :processType
    cookies.delete :accessToken
    cookies.delete :email
  end

  def set_default_agenda
    @webhook_data = WebhookCallDetail.find_by_access_token(cookies[:accessToken])
    @agenda = current_client.agenda_apps.first || current_client.create_agenda
    @agenda.update(type: "Timify", timify_email: cookies[:email]) # unless @agenda.class.name=="Timify"
    @agenda = current_client.agenda_apps.first
    Timify.handle_access({type: @webhook_data.auth_data['type'], email: cookies[:email], access_token: cookies[:accessToken]})
  end
end
