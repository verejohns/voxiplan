class ContactUsController < ApplicationController
  include ApplicationHelper

  before_action :check_ory_session
  layout 'layout'


  def index

  end

end
