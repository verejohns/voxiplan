require 'rails_helper'

RSpec.describe WebhooksController, type: :controller do
  let(:client) {
    Client.create(
      email: 'test@ex.com',
      first_name: 'test', last_name: 'ex', country: 'PK', phone: '03000400100',
      time_zone: 'Asia/Karachi')
  }
  let(:ivr) { client.ivrs.first }

  it 'should return error if secret_key is not provided' do
    skip 'We can add this check to make sure that only VoxiSMS can send requests to this URL'
    # ENV['VOXIPLAN_SECRET_KEY'] is not being used currently
    res  = post :voxi_sms, params: { to: '923000400100', from: '923000400200'}
    expect(res.code).to eq '401'
    expect(res.body).to include 'Invalid secret key'
  end

  describe 'voxi sms ' do
    let(:text_msg) { TextMessage.create(content: 'Message 1', from: '+923000400101', to: '+923000400102') }
    before do
      ivr.preference['sms_engin'] = 'voxi_sms'
      ivr.preference['voxi_sms_customer_id'] = '923000400101'
      ivr.preference['sms_from'] = '+923000400101'
      ivr.save
      text_msg
    end
    it 'should create incoming sms and update conversation' do
      params = {
        :content => "Message 2",
        :event => "incoming_message",
        :from_number => "+923000400102",
        :id => "5f60f745-6c70-4f4b-ab4e-2eb4d77da9fd",
        :time_sent => 1565543991330,
        :customer_id => "923000400101"
      }
      expect { post :voxi_sms, params: params }.to change{TextMessage.count}.by(1).and change { Conversation.count}.by(0)
      msg = TextMessage.last
      expect(msg.content).to eq params[:content]
    end

    it 'should handle SMS sent webhook' do
      params = {
        id: text_msg.uuid,
        message: "TEST 123 c",
        recipient: "+32484605311",
        status: -1,
        statusText: "SMS sent",
        time: 1567707866513,
        type: 1
      }

      post :voxi_sms, params: params
      expect(text_msg.reload.status).to eq -1
      expect(text_msg.time_sent).to_not eq nil
    end

    it 'should handle SMS Delivered webhook' do
      params = {
        id: text_msg.uuid,
        message: "TEST 123 c",
        recipient: "+32484605311",
        status: 9,
        statusText: "SMS Delivered",
        time: 1567707867518,
        type: 2
      }
      post :voxi_sms, params: params
      expect(text_msg.reload.status).to eq 9
      expect(text_msg.time_sent).to eq nil
    end
  end
end
