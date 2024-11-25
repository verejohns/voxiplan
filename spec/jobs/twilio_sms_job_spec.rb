require 'rails_helper'

RSpec.describe TwilioSMSJob, type: :job, vcr: true do
  let(:client) {
    Client.create(
      email: 'test@ex.com',
      first_name: 'test', last_name: 'ex', country: 'PK', phone: '03211223344',
      time_zone: 'Asia/Karachi')
  }
  let(:call){client.ivrs.first.calls.create}
  let(:test_sms) {TextMessage.create(to: '32484605311', content: 'Voxiplan Twilio Test', call: call, ivr: client.ivrs.first)}

  include ActiveJob::TestHelper

  subject(:job) { described_class.perform_later(test_sms.id) }

  it "queues the job" do
    expect { job }.to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size).by(1)
  end

  it "matches with enqueued job" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
  end

  it "is in default queue" do
    expect(described_class.new.queue_name).to eq("default")
  end

  it "executes perform" do
    perform_enqueued_jobs { job }
    expect(test_sms.reload.error_message).to be_nil
  end
end
