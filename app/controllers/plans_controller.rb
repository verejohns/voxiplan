class PlansController < ApplicationController
  layout 'layout'

  def index
    @plans = Plan.all
  end
end
