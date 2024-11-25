class AvailablitiesController < ApplicationController
  include ApplicationHelper

  skip_before_action :verify_authenticity_token
  before_action :check_ory_session
  before_action :set_default_schedule, only: [:index, :save_schedule]

  layout 'layout'

  def index
    redirect_to availablity_path(@default_schedule.id)
  end

  def save_schedule
    if params[:user_action] == 'new'
      new_schedule = current_client.schedule_templates.new(template_name: params[:template_name], is_default: false)
      new_schedule.save
      new_availability = Availability.new(schedule_template_id: new_schedule.id, availabilities: @default_schedule.availability.availabilities)
      new_availability.save
      render json: {result: 'success', redirect_url: availablity_path(new_schedule.id) }
    else
      schedule = current_client.schedule_templates.find(params[:schedule_id])
      schedule.update(template_name: params[:template_name])
      render json: {result: 'success', redirect_url: '' }
    end
  end

  def clone_schedule
    schedule = current_client.schedule_templates.find(params[:schedule_id])
    new_schedule = current_client.schedule_templates.new(template_name: schedule.template_name + ' (clone)', is_default: false)
    new_schedule.save
    new_availability = Availability.new(schedule_template_id: new_schedule.id, availabilities: schedule.availability.availabilities)
    new_availability.save
    render json: {result: 'success', redirect_url: availablity_path(new_schedule.id) }
  end

  def set_as_default
    current_client.schedule_templates.where(is_default: true).update(is_default: false)
    current_client.schedule_templates.find(params[:schedule_id]).update(is_default: true)
    render json: {result: 'success', redirect_url: '' }
  end

  def delete_schedule
    schedule = current_client.schedule_templates.find(params[:schedule_id])
    is_default = schedule.is_default
    schedule.destroy
    if is_default
      first_schedule = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc).first
      first_schedule.update(is_default: true)
    end
    first_schedule = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc).first
    render json: {result: 'success', redirect_url: availablity_path(first_schedule.id) }
  end

  def save_availability
    availability_hours = availabilities_hours(params[:business_hours])
    override_hours = override_hours(params[:override_hours])

    schedule = current_client.schedule_templates.find(params[:schedule_id])
    schedule.availability.availabilities = availability_hours
    schedule.availability.overrides = override_hours
    schedule.availability.save
    render json: {result: 'success', redirect_url: '' }
  end

  def show
    @schedule_templates = current_client.schedule_templates.all.order(is_default: :desc).order(created_at: :desc)
    @selected_schedule = current_client.schedule_templates.find(params[:id])
    @availability = @selected_schedule.availability.availabilities
    @overrides = @selected_schedule.availability.overrides
  end

  private
  def set_default_schedule
    @default_schedule = current_client.schedule_templates.where(is_default: true).first if current_client
  end
end
