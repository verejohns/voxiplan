require 'rails_helper'
require 'support/common_helpers'

RSpec.describe IvrController, type: :controller do
  include CommonHelpers
  include Devise::Test::ControllerHelpers

  let(:data) { {current_time: Time.current, current_call_id: Call.create(ivr: ivr)} }
  let(:ivr_options){ {ai_bot: true} }

  def ivr
    @ivr ||= Ivr.create(name: 'test', client: client, options: ivr_options)
  end

  before do
    Time.zone = 'Asia/Karachi'
    controller.session.clear
    controller.session[:data] = data
  end

  describe 'ai_bot', vcr: true do

    it 'should set time' do
      current_node = find_node('ai_bot_start_conversation')
      @resp = get :run, id: current_node.id

      expect(ask_say).to match('welcome to Appointment bot')
      current_node = find_node('ai_bot_gather')
      @resp = get :run, id: current_node.id, parse_response: true, test_input: 'tomorrow at 10 am'
      expect(ask_say).to match('2019-03-10T10:00')
    end

  end
end