class IvrsController < ApplicationController
  include ApplicationHelper

  before_action :check_ory_session
  skip_before_action :verify_authenticity_token, only: [:create]

  before_action :set_client, only: [:new, :create, :edit, :update, :billing]
  before_action :set_ivr, only: [:edit, :update, :billing]

  def new
    @ivr = Ivr.new
    2.times {@ivr.identifiers.build}
  end

  def create
    if ivr_params[:name].present? and params["ivr"]["booking_url"].present?
      @ivr = @client.ivrs.build({ name: ivr_params[:name], booking_url: params["ivr"]["booking_url"], organization_id: session[:current_organization].id })
      if @ivr.save
        service_30 = Service.new(ivr_id: @ivr.id, client_id: @client.id, enabled: true, is_default: true, duration: 30, name: t('services.demo.label2'), ename: t('services.demo.label2'))
        service_30.save

        service_30_dup = Service.new(eid: service_30.id, agenda_type: 'ClassicAgenda', order_id: (service_30.order_id || 0) + 1, ivr_id: @ivr.id, client_id: @client.id, enabled: true, is_default: true, duration: 30, name: t('services.demo.label2'), ename: t('services.demo.label2'))
        service_30_dup.save

        services = Service.where(ivr_id: @ivr.id, client_id: @client.id)
        services.update_all(preference: {"pre_confirmation"=>"false", "enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"false", "sms_enabled"=>"false", "ai_phone_assistant_enabled"=>"false"})
        Service.where(id: service_30_dup.id).update_all(client_id: nil)

        resource = Resource.new(ivr_id: @ivr.id, client_id: @client.id, enabled: true, is_default: true, name: @client.full_name, ename: @client.full_name)
        resource.save
        resource_dup = Resource.new(ivr_id: @ivr.id, client_id: @client.id, enabled: true, is_default: true, name: @client.full_name, ename: @client.full_name, eid: resource.id)
        resource_dup.save
        # resources = Resource.where(ivr_id: @ivr.id, client_id: @client.id)
        # resources.update_all(preference: {"enabled"=>"true", "widget_enabled"=>"true", "phone_assistant_enabled"=>"true", "chat_enabled"=>"true", "sms_enabled"=>"true", "ai_phone_assistant_enabled"=>"false"})
        Resource.where(id: resource_dup.id).update_all(client_id: nil, agenda_type: "ClassicAgenda")

        service_30.resource_ids = [resource.id]
        service_30_dup.resource_ids = [resource_dup.id]

        if service_30.questions.where(answer_type: 'mandatory').count.zero?
          question = service_30.questions.new(text: 'first_lastname', answer_type: 'mandatory', enabled: true)
          question.save
        end

        current_client.ivrs.each do |ivr|
          unless service_30.reminder
            email_invitee_subject = t('mails.reminder_email_invitee.subject')
            email_invitee_body = t('mails.reminder_email_invitee.body')
            sms_invitee_body = t('mails.reminder_sms_invitee.body')
            Reminder.create(advance_time_offset: 10, advance_time_duration: '-', time: '', sms: false, email: false, email_subject: email_invitee_subject, text: email_invitee_body, email_subject_host: email_invitee_subject, text_host: email_invitee_body,
                            sms_text: sms_invitee_body, client_id: current_client.id, ivr_id: ivr.id, service_id: service_30.id, enabled: true)
          end
        end

        added_calendar_id = nil
        conflict_calendar_ids = []
        application_id = nil
        application_access_token = nil
        application_refresh_token = nil
        application_sub = nil

        application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id )
        application_calendars.each do |application_calendar|
          added_calendar_id = application_calendar.calendar_id unless application_calendar.calendar_id.nil?
          conflict_calendar_ids.push(application_calendar.conflict_calendars) unless application_calendar.conflict_calendars.nil?
          application_id = application_calendar.calendar_id unless application_calendar.calendar_id.nil?
          application_access_token = application_calendar.access_token unless application_calendar.access_token.nil?
          application_refresh_token = application_calendar.refresh_token unless application_calendar.refresh_token.nil?
          application_sub = application_calendar.application_sub unless application_calendar.application_sub.nil?
        end

        current_client.agenda_apps.each do |agenda|
          added_calendar_id = agenda.calendar_id unless agenda.calendar_id.nil?
          conflict_calendar_ids.push(agenda.conflict_calendars) unless agenda.conflict_calendars.nil?
          application_id = agenda.calendar_id unless agenda.calendar_id.nil?
          application_access_token = agenda.cronofy_access_token unless agenda.cronofy_access_token.nil?
          application_refresh_token = agenda.cronofy_refresh_token unless agenda.cronofy_refresh_token.nil?
          application_sub = agenda.cronofy_account_id unless agenda.cronofy_account_id.nil?
        end

        resource.update_attributes(
          calendar_id: added_calendar_id,
          conflict_calendars: conflict_calendar_ids.count.zero? ? nil : conflict_calendar_ids.join(','),
          application_calendar_id: application_id,
          application_access_token: application_access_token,
          application_refresh_token: application_refresh_token,
          application_sub: application_sub,
          )
      end
    end
    cookies['current_ivr_id'] = @ivr.try(:id) || params[:ivr_id]
    return render json: { success: true, message: t('add_workspace.create_message') }, status: 200
  rescue => e
    return render json: { success: false, message: t('common.save_failure') }, status: 500
  end

  def edit
    puts "********* coutn ", @ivr.identifiers
    2.times {@ivr.identifiers.build}
  end

  def update
    respond_to do |format|
      if @ivr.update(ivr_params)
        format.html { redirect_back fallback_location: @client, notice: 'Successfully updated.' }
      else
        format.html { render :new }
      end
    end
  end

  def check_exist_url
    if request.post?
      voxiplan_url = params["voxiplan_url"]
      ivr_id = params["ivr_id"]

      if Ivr.where('booking_url = ? AND id != ?', voxiplan_url, ivr_id).first
        render json: { existed: true }, status: 200
      else
        render json: { existed: false }, status: 200
      end
    end
  end

  def update_url
    if request.post?
      voxiplan_url = params["voxiplan_url"]
      ivr_id = params["ivr_id"]

      if Ivr.where('booking_url = ? AND id != ?', voxiplan_url, ivr_id).first
        render json: { result: 'existed' }, status: 200
      else
        current_client.ivrs.find(ivr_id).update_columns(booking_url: voxiplan_url)

        render json: { result: 'success', voxiplan_url: voxiplan_url }, status: 200
      end
    end
  end

  def update_name
    if request.post?
      ivr_id = params[:ivr_id]
      ivr_name = params[:ivr_name]
      Ivr.find(ivr_id).update_columns(name: ivr_name)
      render json: { result: 'success', message: t('common.save_success') }
    end
  rescue => e
    render json: { result: 'error', message: e.message }
  end

  def change_ivr
    cookies['current_ivr_id'] = params[:ivr]
    redirect_back fallback_location: root_path
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def set_ivr
    @ivr = @client.ivrs.find(params[:id])
  end

  def ivr_params
    p = params.require(:ivr).permit(:id, :name, :voice, :confirmation_sms, :agent_number, settings: setting_params, identifiers_attributes: [:id, :identifier])
    # destroy blank
    p[:identifiers_attributes].each{|_,e| e.merge!(_destroy: '1') if e[:identifier].blank?} if p[:identifiers_attributes]
    p
  end


  def setting_params
    %i[voice_engin sms_engin sms_from voxi_sms_customer_id voxi_sms_api_key]
  end
end
