require 'rails_helper'

RSpec.describe Ivr, type: :model do

  let(:client) {
    Client.create(
      email: 'test@ex.com',
      first_name: 'test', last_name: 'ex', country: 'PK', phone: '03215110224'
    )
  }
  let(:ivr) {Ivr.create(name: 'test', client: client)}

  describe 'default_values' do
    it 'should set proper defaults' do
      expect(ivr.persisted?)
      expect(ivr.voice).to include 'Neural2'
      expect(ivr.preference['allow_new_customers']).to_not be_nil
      expect(ivr.preference['allow_new_customers']).to be_truthy
    end
  end

  describe '#find_node' do
    subject{ivr.find_node('welcome_open')}
    it 'finds node by name' do
      expect(subject).to_not be_nil
      expect(subject.name).to eq 'welcome_open'
    end
  end

end
