class RecordingsController < ApplicationController
  layout false
  def show
    @recording = Recording.find_by uuid: params[:id]
  end
end
