require 'rails_helper'

RSpec.describe MobminderParty, type: :model, vcr: {cassette_name:  'mobminder'} do
  let(:client) { MobminderParty.new(MM_LOGIN, MM_PASSWORD, MM_KEY ) }

  describe 'visitors', vcr: {cassette_name: 'mobminder_customers'} do

    it 'should get customers by mobile' do
      customers = client.visitors(mobile: '5599')
      expect(customers).to_not be_empty
    end

    it 'should create a visitor ' do
      customer =
        client.create_visitor(
          firstname: 'Shan', lastname: 'ROR',
          mobile: '+919770555563', email: 'shan.ror@gmail.com',
          birthday: Date.parse('1990-12-31')
        )
      expect(customer[:id])
    end
  end

  describe 'appointments' do
    it 'should get all appointments for a customer' do
      appointments = client.appointments(id: '3790419')
      expect(appointments.first).to include(
                                'id' => a_kind_of(String),
                                'cueIn' => a_kind_of(String),
                              )
    end
  end


end