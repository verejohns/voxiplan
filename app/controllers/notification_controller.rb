class NotificationController < ApplicationController
  skip_before_action :verify_authenticity_token

  def add_notification
    notification = Notification.new(client_id: params[:client_id], changes_since: params[:notification][:changes_since], channel_id: params[:channel][:channel_id])
    notification.save
  end

  def get_notification
    new_notificaitons = Notification.where(client_id: params[:client_id])
    if new_notificaitons.count.zero?
      render json: { 'has_new': 'no' }
    else
      new_notificaitons.destroy_all
      render json: { 'has_new': 'yes' }
    end
  end
end
