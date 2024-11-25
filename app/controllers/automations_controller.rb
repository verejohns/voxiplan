class AutomationsController < ApplicationController
  skip_before_action :verify_authenticity_token
  include ApplicationHelper
  before_action :check_ory_session
  layout 'layout'

  def index

  end
end
