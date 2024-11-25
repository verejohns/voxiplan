require 'rails_helper'
require 'support/common_helpers'

RSpec.describe AgendaApi, type: :model do
  include CommonHelpers

  def text_nl(txt)
    txt + " \n "
  end


  let(:agenda) {SuperSaas.create(ss_schedule_id: SS_SCHEDULE_ID, ss_checksum: SS_CHECKSUM)}
  let(:ivr) {double(id: 1, agenda_app: agenda, nodes: double(find_by: nil), voice: 'alice', voice_locale: 'en-US', preference: {'voice_engin' => 'twilio'})}
  let(:data) {{}}
  let(:free_slots){ YAML.load_file('spec/support/ss_3_slots.yml') }

  let(:appointment_menu3_opts) do
    appointment_menu3_text = {
        key1: I18n.t('static_ivr.appointment_group_menu3.time1', time1: 'slot1_start'),
        key2: I18n.t('static_ivr.appointment_group_menu3.time2', time2: 'slot2_start'),
        key3: I18n.t('static_ivr.appointment_group_menu3.time3', time3: 'slot3_start'),
        other: I18n.t('static_ivr.appointment_group_menu3.other')
    }
    appointment_menu3_opts = {
        name: 'appointment_menu3',
        text: appointment_menu3_text,
        timeout: 5, tries: 1,
        timeout_next: 'agenda_slot_availabilities', invalid_next: 'appointment_menu3',
        parameters: {'time_format': 'hour'},
        choices: {key_1: 'confirm1', key_2: 'confirm2', key_3: 'confirm3', key_4: 'appointment_menu4',  key_9: 'appointment_menu3', key_0: 'transfer_or_voicemail'}
    }
  end

  let(:next_node){
    Menu.new(appointment_menu3_opts)
  }

  let(:new_menu){
    Menu.new(appointment_menu3_opts)
  }

  subject do
    AgendaApi.new(
      name: 'agenda_slot_availabilities',
      method_name: 'free_slots',
      parameters: {number_of_slots: 3, after_time: Time.current, options: {}},
      results: [{start: 'slot1_start', sid: 'slot1_sid'},
                {start: 'slot2_start', sid: 'slot2_sid'},
                {start: 'slot3_start', sid: 'slot3_sid'}],
      next: 'appointment_menu3'
    )
  end

  before do
    allow_any_instance_of(Node).to receive(:data).and_return(data)
    allow(next_node).to receive(:ivr).and_return(ivr)
    allow(next_node).to receive(:data).and_return(data)
    allow(subject).to receive(:ivr).and_return(ivr)
    allow(subject).to receive(:next_node).and_return(next_node)
    allow(subject).to receive(:data).and_return(data)
  end

  context 'three available slots', vcr: { cassette_name: 'email_validation'} do
    before {allow(agenda).to receive(:free_slots).and_return(free_slots)}
    it 'should say all three slots' do
      allow(ivr).to receive(:play_enabled?).and_return(false)
      subject.run
      expect(menu1_text(next_node, slot1: '09:30 AM', slot2: '10:00 AM', slot3: '10:30 AM')).to eq menu1_text(new_menu, slot1: '09:30 AM', slot2: '10:00 AM', slot3: '10:30 AM')
      puts subject.data
      expect(subject.data[:slot3_start]).to be_nil
    end
  end

  context 'two available slots', vcr: { cassette_name: 'email_validation'} do
    before {allow(agenda).to receive(:free_slots).and_return(free_slots.first(2))}
    it 'should say two slots' do
      allow(ivr).to receive(:play_enabled?).and_return(false)
      subject.run
      expect(menu1_text(next_node, slot1: '09:30 AM', slot2: '10:00 AM')).to eq menu1_text(new_menu, slot1: '09:30 AM', slot2: '10:00 AM')
      expect(subject.data[:slot3_start]).to be_nil
    end
  end

  context 'one available slot', vcr: { cassette_name: 'email_validation'} do
    before {allow(agenda).to receive(:free_slots).and_return(free_slots.first(1))}
    it 'should say one slot' do
      allow(ivr).to receive(:play_enabled?).and_return(false)
      subject.run
      expect(menu1_text(new_menu, slot1: '09:30 AM')).to eq menu1_text(new_menu, slot1: '09:30 AM')
      expect(subject.data[:slot1_start]).to be_nil
      expect(subject.data[:slot2_start]).to be_nil
    end
  end

  describe 'services' do

    let(:next_node){
      select_service = {
        key1: I18n.t('static_ivr.services.select_single', num: 1, var: 'service_name1'),
        key2: I18n.t('static_ivr.services.select_single', num: 2, var: 'service_name2'),
        key3: I18n.t('static_ivr.services.select_single', num: 3, var: 'service_name3'),
        other: I18n.t('static_ivr.services.other')
      }
      select_service_opts = {
        name: 'select_service',
        text: select_service,
        timeout: 5, tries: 2,
        timeout_next: 'timeout', invalid_next: 'invalid',
        parameters: { 'selected_next' => 'choosen_service'},
        choices: {key_9: 'select_service'}
      }
      Menu.new(select_service_opts)
    }

    subject do
      AgendaApi.new(
        name: 'agenda_slot_availabilities',
        method_name: 'services',
        parameters: {resource: "%{choosen_resource}"},
        results: {id: 'service_id', name: 'service_name'},
        next: 'appointment_menu3'
      )
    end

    # let(:agenda) {SuperSaas.create(ss_schedule_id: SS_SCHEDULE_ID, ss_checksum: SS_CHECKSUM)}
    context 'timify', vcr: { cassette_name: 'timify_services'} do
      let(:agenda) {
        Timify.create(timify_access_token: ENV['TIMIFY_ACCESS_TOKEN'])
      }

      it 'should work ' do
        skip 'no longer valid'
        r = subject.run
        expect(subject.data[:service_id1]).to_not be_nil
        expect(subject.data[:service_id2]).to_not be_nil
        expect(subject.data[:service_id3]).to_not be_nil
        expect(subject.data[:service_name1]).to_not be_nil
        expect(next_node.text).to eq 'For Setup, press 1. For Support, press 2. For test, press 3.  Or press 9 to repeat."'
      end
    end
  end

  describe '#choose_selected' do
    let(:data) {{select_service: 2, service_id2: '123' }}
    subject do
      AgendaApi.new(
        name: 'choosen_service',
        method_name: 'choose_selected',
        parameters: {prefix: 'service_id', selected: "%{select_service}", save_as: 'choosen_service'},
        next: 'appointment_menu3'
      )
    end
    let(:next_node){
      Say.new(name: 'say_done', text: 'Done')
    }
    it 'should select service_id2' do
      allow(ivr).to receive(:play_enabled?).and_return(false)
      subject.run
      expect(subject.data[:choosen_service]).to eq '123'
    end
  end


  describe '#get_after_time' do
    let(:test_time) {Time.zone.local(2019, 01, 23, 9, 00)}
    before { travel_to test_time }
    after  { travel_back }

    it 'should return proper time' do
      n = AgendaApi.new
      expect(n.send(:get_after_time, '%{30_minutes}')).to eq(test_time + 30.minutes)
      expect(n.send(:get_after_time, '%{2_hours}')).to eq(test_time + 2.hours)
      expect(n.send(:get_after_time, '%{1_day}')).to eq((test_time + 1.day).midnight)
    end
  end

end
