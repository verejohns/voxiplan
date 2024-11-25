require 'rails_helper'
require 'support/common_helpers'

RSpec.describe Api::AvailabilityController, type: :controller do
  include CommonHelpers

  let(:identifier) { ivr.identifiers.first.identifier }
  let(:headers) { { 'X-Voxiplan-API-Key' => 'test_b27f8bbb602b9198ac235958801bc8' } }
  let(:params) do
    {
        identifier: identifier
    }
  end

  before do
    request.set_header('X-Voxiplan-API-Key', 'test_b27f8bbb602b9198ac235958801bc8')
  end

  context 'Dummy Agenda' do
    it 'should return free_slots' do
      @resp = get :index, params: params
      expect(json_response).to_not be_nil
    end
  end

  context 'Mobminder' do
    let(:params) {
      {
        identifier: identifier,
        :resource_id=>"13138",
        :service_id=>"16986",
        :start_hour=>"09:00",
        :end_hour=>"13:00",
        :weekday=>"Monday"}
    }

    before do
      ivr.client.create_agenda
      ivr.client.agenda_apps.first.update(type: Mobminder.to_s, mm_login: ENV['MM_LOGIN'], mm_pwd: ENV['MM_PASSWORD'], mm_kid: ENV['MM_KEY'])
    end

    it 'should return free_slots', vcr: true do
      @resp = get :index, params: params
      expect(json_response).to_not be_nil
    end
  end

end