class OrganizationsController < ApplicationController
  include ApplicationHelper
  before_action :check_ory_session
  skip_before_action :verify_authenticity_token

  layout 'layout'

  def show
    redirect_to request.env["HTTP_REFERER"] unless checkRelationTuple("/organization-" + session[:current_organization].id.to_s, "manage", "client-" + current_client.id.to_s)

    invitations = Invitation.where("organization_id = ? AND status LIKE ?", session[:current_organization].id, "accept" + "%")

    @clients = [{ id: current_client.id, full_name: current_client.full_name, email: current_client.email, enable_calendar: true, member_id: current_client.id, role: "owner" }]
    invitations.each do |invitation|
      client = Client.find_by_email(invitation.to_email)
      @clients.push({ id: client.id, full_name: client.full_name, email: client.email, enable_calendar: invitation.enable_calendar, member_id: client.id, role: invitation.role }) if client
    end
  end

  def invite_member
    return render json: {message: 'Email not provided!'}, status: 401 unless params[:email]
    email = params[:email]

    invitation = Invitation.where("to_email = ? AND organization_id = ? And status != ?", email, session[:current_organization].id, "deleted").first
    if invitation
      if invitation.status == "accepted" || invitation.status == "accepting"
        return render json: { success: false, message: t('organization.message.already_accepted') }, status: 200
      elsif invitation.status == "pending"
        return render json: { success: false, message: t('organization.message.already_pending') }, status: 200
      end
    end

    begin
      return render json: { success: false, message: t('organization.message.invalid_email') }, status: 200 if check_invalid_email(email)

      invitation = Invitation.create({ status: "pending", to_email: email, organization_id: session[:current_organization].id, enable_calendar: params[:enable_calendar] == "true" ? true : false, role: params[:role] == "1" ? "member" : "" })

      ClientNotifierMailer.organization_invitation_email(session[:current_organization].name, email, invitation.id).deliver
    rescue => e
      puts e
      invitation.destroy if invitation
      return render json: { success: false, message: t('organization.message.failed_invitation_email') }, status: 200
    end

    return render json: { success: true, message: t('organization.message.success_sent', email: email) }, status: 200
  end

  def check_invalid_email(email)
    return false if email.include? "@e.rainforestqa.com"
    response = HTTParty.get("https://emailvalidation.abstractapi.com/v1/?api_key=#{ENV['EMAIL_VALIDATION_API_KEY']}&email=#{email}")
    response['is_valid_format']['value'] == false || response['is_disposable_email']['value'] == true || response['is_mx_found']['value'] == false || response['deliverability'] != 'DELIVERABLE'
  end

  def handle_calendar
    return render json: {message: 'Member not provided!'}, status: 401 unless params[:member_id]
    client_id = params[:member_id]

    begin
      client = Client.find(client_id)
      invitation = Invitation.where("to_email = ? AND organization_id = ?", client.email, session[:current_organization].id).first

      if invitation
        invitation.update_column(:enable_calendar, !invitation.enable_calendar)

        return render json: { success: true, message: t('organization.message.calendar_enable_changed') }, status: 200
      else
        return render json: { success: false, message: t('organization.message.owner_calendar_enable_changed') }, status: 200
      end
    rescue => e
      puts e
    end
  end

  def remove_member
    return render json: {message: 'Client IDs not provided!'}, status: 401 unless params[:client_ids]
    client_ids = params[:client_ids]

    begin
      client_ids.each do |client_id|
        client = Client.find(client_id)
        invitation = Invitation.where("to_email = ? AND organization_id = ?", client.email, session[:current_organization].id).first

        if invitation
          invitation.destroy
          deleteRelationTuple("/organization-" + session[:current_organization].id.to_s, "member", client.id.to_s)
          return render json: { success: true }, status: 200
        else
          return render json: { success: false }, status: 200
        end
      end
    rescue => e
      return render json: {message: 'DB Error!'}, status: 401
    end
  end

  def calendar
    @application_calendars = ApplicationCalendar.where(organization_id: session[:current_organization].id)
    @calendar_enabled_members = [current_client]
    invitations = Invitation.where("organization_id = ? AND status LIKE ? AND enable_calendar = ?", session[:current_organization].id, "accept" + "%", true)
    invitations.each do |invitation|
      @calendar_enabled_members.push(Client.find_by_email(invitation.to_email))
    end

    @external_calendars = session[:current_organization].agenda_apps
  end

  def save_calendar
    id = params[:id]
    name = params[:name]
    member_id = params[:member_id]

    if id != ''
      application_calendar = ApplicationCalendar.find(id)
      application_calendar.update_columns(
        name: name,
        id: id
      )
    else
      new_application_calendar = ApplicationCalendar.create({ :name => name, :organization_id => session[:current_organization].id, :client_id => member_id })
      application_calendar_id = 'cronofy_calendar_' + new_application_calendar.id

      cronofy = current_client.create_cronofy
      application_calendar = cronofy.application_calendar(application_calendar_id)

      cronofy = current_client.create_cronofy(access_token: application_calendar.access_token, refresh_token: application_calendar.refresh_token)
      calendars = cronofy.list_calendars
      created_calendar = calendars.select{|c| c.calendar_name == application_calendar_id}

      new_application_calendar.update_columns(
        calendar_id: created_calendar[0].calendar_id,
        access_token: application_calendar.access_token,
        refresh_token: application_calendar.refresh_token,
        application_sub: application_calendar.sub,
        conflict_calendars: created_calendar[0].calendar_id,
        calendar_name: created_calendar[0].calendar_name,
      )

      default_resources = Resource.where(client_id: member_id, calendar_type: 'my_calendar', my_calendar_type: 'default')
      default_resources.each do |resource|
        resource.update_columns(calendar_id: new_application_calendar.calendar_id) if resource.calendar_id.nil? || resource.calendar_id == ''

        if resource.conflict_calendars.nil? || resource.conflict_calendars == ''
          resource.update_columns(conflict_calendars: new_application_calendar.conflict_calendars)
        else
          resource.update_columns(conflict_calendars: resource.conflict_calendars + ',' + new_application_calendar.calendar_id)
        end

        if resource.conflict_calendars.nil? || resource.conflict_calendars == '' || resource.calendar_id.nil? || resource.calendar_id == ''
          resource.update_columns(
            application_calendar_id: new_application_calendar.calendar_id,
            application_access_token: new_application_calendar.access_token,
            application_refresh_token: new_application_calendar.refresh_token,
            application_sub: new_application_calendar.application_sub
          )
        end
      end
    end

    return render json: { success: true, message: id != '' ? t('organization.message.edit_calendar_success') : t('organization.message.add_calendar_success') }, status: 200
  end

  def remove_calendar
    return render json: {success: false, message: t('organization.message.non_id')}, status: 401 unless params[:id]

    id = params[:id]

    application_calendar = ApplicationCalendar.find(id)

    if application_calendar
      default_resources = Resource.where(client_id: current_client.id, calendar_type: 'my_calendar', my_calendar_type: 'default')
      calendar_id = default_resources[0].calendar_id
      conflict_calendars = application_calendar.conflict_calendars
      old_calendar_id = application_calendar.calendar_id

      application_calendar.destroy

      if default_resources.count.positive? && calendar_id == old_calendar_id
        agenda_apps = current_client.agenda_apps
        if agenda_apps.count.positive?
          calendar_id = agenda_apps[0].conflict_calendars.split(',').first if agenda_apps[0].conflict_calendars
          agenda_apps[0].update_columns(calendar_id: calendar_id)
        else
          application_calendars = current_client.application_calendars
          calendar_id = application_calendars.count.positive? ? application_calendars[0].calendar_id : nil
        end
      end

      default_resources.each do |default_resource|
        default_resource.update_columns(calendar_id: calendar_id)

        if conflict_calendars
          new_conflict_calendars = default_resource.conflict_calendars
          index = new_conflict_calendars.index(conflict_calendars)

          unless index.nil?
            if index.positive?
              new_conflict_calendars.slice! ",#{conflict_calendars}"
            else
              if new_conflict_calendars == conflict_calendars
                new_conflict_calendars = ""
              else
                new_conflict_calendars.slice! "#{conflict_calendars},"
              end
            end

            default_resource.update_columns(conflict_calendars: new_conflict_calendars)
          end
        end
      end

      return render json: { success: true, message: t('organization.message.remove_calendar_success') }, status: 200
    else
      return render json: { success: false, message: t('organization.message.non_existed_calendar') }, status: 401
    end
  rescue => e
    puts e
    return render json: { success: false, message: e.message }, status: 500
  end

  def set_organization
    session[:current_organization] = Organization.find(params[:id])

    current_client.ivrs.each do |ivr|
      default_resources = ivr.resources.where('calendar_type = ? and my_calendar_type = ? and client_id IS NOT NULL', 'my_calendar', 'default')
      agenda = current_client.agenda_apps
      application_calendar = ApplicationCalendar.where(organization_id: session[:current_organization].id, client_id: current_client.id).first
      added_agenda = agenda.where('calendar_id IS NOT NULL')

      if added_agenda.count.positive?
        calendar_id = added_agenda.first.calendar_id
      elsif application_calendar
        calendar_id = application_calendar.calendar_id
      else
        calendar_id = ""
      end

      conflict_calendars = ""
      conflict_calendars = application_calendar.conflict_calendars if application_calendar
      agenda.each do |item|
        conflict_calendars = conflict_calendars == "" ? conflict_calendars + item.conflict_calendars : conflict_calendars + ',' + item.conflict_calendars
      end

      default_resources.update_all(
        calendar_id: calendar_id,
        conflict_calendars: conflict_calendars
      )
    end

    return render json: { success: true }, status: 200
  rescue => e
    puts e
    return render json: { success: false }, status: 500
  end
end
