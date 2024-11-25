require 'rails_helper'

RSpec.describe ClientsController, type: :controller do
  let(:client) { Client.create(
    email: 'test@ex.com',
    first_name: 'test', last_name: 'ex', country: 'PK', phone: '03211223344')
  }
  let(:ivr) { Ivr.create(name: 'test', client: client) }
  let(:agenda_app) { Timify.create(timify_access_token: ENV['TIMIFY_ACCESS_TOKEN'], ivr: ivr) }
  delegate :t, to: :I18n
  let(:data) { {current_time: Time.current} }
  let(:test_time){ Time.utc(2018, 04, 23, 9, 00) }
  
  before do
    sign_in client
  end

  def find_node(name)
    ivr.nodes.find_by name: name
  end

  describe 'Call Forwarding' do
    context 'GET call_forwarding', vcr: { cassette_name: 'call_forwarding'} do
      it 'should return call forwarding node' do
        get :call_forwarding
        expect(response.status).to eq(200)
        expect(assigns(:call_forwarding).name).to eq("transfer_to_agent")
      end
    end

    context 'POST call_forwarding', vcr: { cassette_name: 'call_forwarding'} do
      it 'should update text for call forwarding node' do
        msg = "This is a test message"
        post :call_forwarding, params: {:call_forwarding => {
                                                        :text => msg
                                                      }
                                    }
        expect(response.status).to eq(200)
        expect(assigns(:call_forwarding).name).to eq("transfer_to_agent")
        expect(assigns(:call_forwarding).text).to eq(msg)
      end

    end
  end

end