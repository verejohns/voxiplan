require 'rails_helper'

RSpec.describe TextMessage, type: :model do
  before do
    allow_any_instance_of(TextMessage).to receive(:shorten_urls_enabled?).and_return(true)
  end
  it 'should replace URLs with short URL' do
    ENV['SHORT_URL_HOST'] = 'http://short.com/'
    t = TextMessage.new(content: '1) a.com 2) http://b.com/ 3) https://c.d.com 4) x.com.', to: '+923000400100', from: '+923000400101')
    expect{t.save}.to change{Shortener::ShortenedUrl.count}.by(4)
    expect(t.reload.content).to_not include('a.com')
    expect(t.content).to include('short.com')
    expect(t.content[-1]).to_not eql('.')
  end

  it 'should create conversation' do
    t = TextMessage.new(content: 'hello', to: '+923000400100', from: '+923000400101')
    expect{t.save}.to change{Conversation.count}.by(1)
    expect(t.reload.conversation.to).to eq t.to
    expect(t.reload.conversation.from).to eq t.from

    t = TextMessage.new(content: 'hello 2', to: '+923000400100', from: '+923000400101')
    expect{t.save}.to_not change{Conversation.count}

    expect(t.conversation.text_messages.size).to eq 2
  end
end
