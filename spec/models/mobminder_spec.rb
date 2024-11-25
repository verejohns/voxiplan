require 'rails_helper'

RSpec.describe Mobminder, type: :model, vcr: { cassette_name: 'mobminder'} do
  let(:client) { Client.create(
    email: 'test@ex.com',
    first_name: 'test', last_name: 'ex', country: 'PK', phone: '03211223344',
    time_zone: 'Europe/Brussels')
  }
  let(:ivr) { Ivr.create(name: 'test', client: client) }

  let(:agenda_app) {
    Mobminder.create(mm_login: ENV['MM_LOGIN'], mm_pwd: ENV['MM_PASSWORD'], mm_kid: ENV['MM_KEY'], ivr: ivr)
  }

  let(:test_time){Time.zone.local(2018, 06, 11, 9, 00)}

  before do
    travel_to test_time
    DummyAgenda.destroy_all
    ivr.resources.destroy_all
    ivr.services.destroy_all
  end

  describe 'slots' do
    describe '#all_resources' do
      it 'returns a bCal and a random u/fCal' do
        allow_any_instance_of(Mobminder).to receive(:resources).and_return([{"id"=>"3", "name"=>"C"}, {"id"=>"2", "name"=>"A"}, {"id"=>"1", "name"=>"B"}])
        allow_any_instance_of(Mobminder).to receive(:resource_type).with("1").and_return(:bCals)
        allow_any_instance_of(Mobminder).to receive(:resource_type).with("2").and_return(:uCals)
        allow_any_instance_of(Mobminder).to receive(:resource_type).with("3").and_return(:fCals)
        expect(agenda_app.all_resources('x','1')[:fCals]).to be_present
        expect(agenda_app.all_resources('x','2')[:fCals]).to be_present
      end

      it 'return only one bCal if no other extra_resources type is available' do
        allow_any_instance_of(Mobminder).to receive(:resources).and_return([{"id"=>"3", "name"=>"C"}, {"id"=>"2", "name"=>"A"}, {"id"=>"1", "name"=>"B"}])
        allow_any_instance_of(Mobminder).to receive(:resource_type).and_return(:bCals)
        expect(agenda_app.all_resources('x','1').size).to eq(1)
      end
    end
  end

  describe 'Customers' do
    describe '#find_customer' do
      it 'find existing customer on online agenda' do
        customer = agenda_app.find_customer(phone: '112233445')
        expect(customer).to_not be_nil
        expect(customer).to include(
                              'firstname' => a_kind_of(String),
                              'lastname' => a_kind_of(String)
                            )
      end
    end


    describe '#create_local_customer' do
      it 'find existing customer on online agenda' do
        agenda_customer = agenda_app.find_customer(phone: '112233445')
        customer = agenda_app.create_local_customer(agenda_customer)
        expect(customer.persisted?).to be_truthy
        expect(customer.eid).to be_a_kind_of(String)
        expect(customer.first_name).to be_a_kind_of(String)
        expect(customer.last_name).to be_a_kind_of(String)
      end
    end
  end

  describe '#services' do
    it 'should return all services' do
      r = agenda_app.services
      puts r.to_yaml
      expect(r).to be_an_instance_of Array
      expect(r.count).to eq 5
    end

    it 'should return services for a specific resource' do
      r = agenda_app.services(resource_id: '13137')
      puts r.to_yaml
      expect(r).to be_an_instance_of Array
      expect(r.count).to eq 2
    end

    it 'should create local services' do
      expect(ivr.services.count).to eq 0
      service_ids = %w[15648 15649]
      agenda_app.configure_services(service_ids)
      intersection = ivr.services.pluck(:eid) | service_ids
      expect(intersection.size).to eq 2

      first_service = service_ids.first(1)
      s = Service.find_by(eid: first_service)
      s .update_column(:ename, 'old name')
      old = s

      expect(ivr.services.active.size).to eq 2
      agenda_app.configure_services(first_service)
      expect(ivr.services.active.size).to eq 2

      expect(old.ename).to_not eq s.reload.name
      expect(old.id).to eq s.id
    end

  end

  describe '#resources' do
    it 'should return all resources' do
      r = agenda_app.resources
      puts r.to_yaml
      expect(r).to be_an_instance_of Array
      expect(r.count).to eq 4
    end

    it 'should return resources for a specific service' do
      r = agenda_app.resources(service_id: '13805' )
      puts r.to_yaml
      expect(r).to be_an_instance_of Array
      expect(r.count).to eq 1
    end


    it 'should create local resources' do
      expect(ivr.resources.count).to eq 0
      resource_ids = %w[13138 13139]
      agenda_app.configure_resources(resource_ids)
      intersection = ivr.resources.active.pluck(:eid) | resource_ids
      expect(intersection.size).to eq 2
    end
  end

  describe '#existing_appointments' do
    it 'should get all appointments' do
      result = agenda_app.existing_appointments(agenda_customer_id: '3790419')
      expect(result.first).to include(
                                'id' => a_kind_of(String),
                                'time' => a_kind_of(DateTime),
                              )

    end
  end

  describe 'create_customer_on_agenda' do
    let(:customer) { Customer.create(first_name: 'first_name', last_name: 'last_name', phone_number: '32484605314', phone_country: 'BE')}
    it 'should create customer on agenda' do
      r = agenda_app.create_customer_on_agenda(customer.id)
      expect(r).to be_truthy
    end
  end

  describe '#delete_appointment' do
    it 'should delete an appointment' do
      id = '8993699'
      result = agenda_app.delete_appointment(id)
      expect(result).to be_truthy
    end
  end

end
