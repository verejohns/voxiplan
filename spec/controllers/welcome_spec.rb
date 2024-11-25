require 'rails_helper'
require 'support/common_helpers'

RSpec.describe IvrController, type: :controller do
  include CommonHelpers
  # let(:test_time){ Time.zone.local(2018, 04, 23, 9, 00) }

  before do
    initial_setup
  end

  describe 'welcome' do
    context 'when open' do
      before { travel_to Time.current.midnight + 10.hours }
      after { travel_back }
      it 'should say open message' do
        get :run
        expect(say).to eq t('static_ivr.welcome_open')
        expect(next_url).to eq next_node_path('check_caller_id')
      end
    end

    context 'when close' do
      before{allow_any_instance_of(Biz::Schedule).to receive(:in_hours?).and_return(false)}
      it 'should say close message' do
        get :run
        expect(say).to eq t('static_ivr.welcome_closed')
        expect(next_url).to eq next_node_path('check_caller_id')
      end
    end
  end
end