require 'rails_helper'
require 'support/common_helpers'

RSpec.describe IvrController, type: :controller do
  include CommonHelpers
  # include Devise::Test::ControllerHelpers
  include ActiveJob::TestHelper

  let(:current_call) { Call.create(ivr: ivr) }
  let(:data) { {current_time: Time.current, current_call_id: current_call.id} }
  let(:test_time){ Time.zone.local(2018, 04, 23, 9, 00) }

  let(:clean_dummy_agenda) do
    DummyAgenda.destroy_all
    ivr.resources.destroy_all
    ivr.services.destroy_all
  end

  before do
    initial_setup
    clean_dummy_agenda
  end

  describe 'IVR preferences' do
    it 'should set ivr preference in session data' do
      get :run
      expect(session[:data][:ivr_preference_allow_new_customers]).to be_truthy
    end
  end

  describe 'announcement_open' do
    let(:current_node) {find_node('announcement_open')}
    it 'should say open msg' do
      current_node.update(enabled: true)
      get :run, params: {id: current_node.id}
      expect(say).to eq t('static_ivr.announcement_open')
      expect(next_url).to eq next_node_path('menu_open')
    end
  end

  describe 'announcement_close' do
    let(:current_node) {find_node('announcement_closed')}
    it 'should say open msg' do
      current_node.update(enabled: true)
      get :run, params: {id: current_node.id}
      expect(say).to eq t('static_ivr.announcement_closed')
      expect(next_url).to eq next_node_path('menu_closed')
    end
  end

  describe 'menu_open' do
    let(:current_node) {find_node('menu_open')}
    it 'should say open msg' do
      get :run, params: {id: current_node.id}
      expect(ask_say).to eq t('static_ivr.menu_open')
      expect(next_url).to eq next_node_path('menu_open')
    end
  end

  describe 'menu_close' do
    let(:current_node) {find_node('menu_closed')}
    it 'should say open msg' do
      get :run, params: {id: current_node.id}
      expect(ask_say).to eq t('static_ivr.menu_closed')
      expect(next_url).to eq next_node_path('menu_closed')
    end
  end

  describe 'internal error' do
    let(:current_node) {ivr.nodes.first}

    before do
      allow_any_instance_of(current_node.class).to receive(:execute).and_raise('An error')
    end

    it 'test exceptions' do
      get :run
      expect{current_node.execute}.to raise_error('An error')
    end

    it 'handles exceptions' do
      get :run
      expect(say).to eq t('static_ivr.internal_error')
      expect(next_url).to eq next_node_path('transfer_or_voicemail')
    end
  end

  describe 'check_caller_id' do
    let(:current_node) {find_node('check_caller_id')}

    it 'should ask number if caller_id is unknown' do
      get :run, params: {id: current_node.id,  cid: '+8656696'}
      expect(ask_say).to eq t('static_ivr.gather_number')
    end

    it 'should ask number if caller_id is restricted' do
      get :run, params: {id: current_node.id, cid: '+8656696'}
      expect(ask_say).to eq t('static_ivr.gather_number')
    end

    it 'should ask number if caller_id is nil' do
      get :run, params: {id: current_node.id}
      expect(ask_say).to eq t('static_ivr.gather_number')
    end

    it 'should not ask number if caller_id is known' do
      data[:ivr_preference_allow_new_customers] = true
      get :run, params: {id: current_node.id, cid: '123456748'}
      expect(ask_say).to eq t('static_ivr.menu_closed')
    end
  end

  describe 'gather phone number' do
    let(:current_node) {find_node('gather_number')}

    it 'should ask for a number' do
      get :run, params: {id: current_node.id}
      expect(ask_say).to eq t('static_ivr.gather_number')
    end

    it 'should ask number again when invalid number is given' do
      get :run, params: {id: next_node.id, test_input: '12345678', parse_response: true}
      expect(say).to eq t('static_ivr.say_invalid_number')
      # again ask for number
      expect(next_url).to eq next_node_path(current_node.name)
    end

    it 'should ask number again when not number is given' do
      # make sure tropo also sets blank
      get :run, params: {id: next_node.id, test_input: '', parse_response: true}
      expect(say).to eq t('static_ivr.say_invalid_number')
      expect(next_url).to eq next_node_path(current_node.name)
    end
  end

  describe 'agenda apps', vcr: true do
    let(:test_time) {Time.zone.local(2018, 04, 23, 9, 00)}
    before do
      travel_to test_time
      allow_any_instance_of(IvrController).to receive(:ivr).and_return(ivr)
      agenda_app
    end

    after  { travel_back }

    context 'agenda_app is missing' do
      let(:agenda_app){nil}
      before do
        # ivr.update(agenda_app: nil)
        # ivr.save
        # ivr.agenda_app.each do |agenda|
        #   agenda.destroy
        # end
      end
      let(:current_node) {find_node('agenda_group_availabilities')}

      it 'says internal error and asks for transfer' do
        get :run, params: {id: current_node}
        # expect(say).to be_nil
        expect(say).to eq t('static_ivr.internal_error')
        # expect(next_url).to eq next_node_path('transfer_or_voicemail')
      end
    end

    context 'agenda creds missing' do
      let(:agenda_app) {
        SuperSaas.create(ivr: ivr, client: ivr.client)
      }
      let(:current_node) {find_node('agenda_group_availabilities')}

      it 'says internal error and asks for transfer' do
        # TODO: Save API call if creds are missing
        get :run, params: {id: current_node}
        expect(say).to eq t('static_ivr.internal_error')
      end
    end

    describe 'fifo + constraints' do
      before do
        allow_any_instance_of(Node).to receive(:data) { controller.session[:data].symbolize_keys! }
      end
      # context 'super_saas', vcr: { cassette_name: 'ss_availabilities'} do
      #   let(:agenda_app) {
      #     SuperSaas.create(ss_schedule_id: SS_SCHEDULE_ID, ss_checksum: SS_CHECKSUM, ivr: ivr, client: ivr.client)
      #   }
      #
      #   it 'gets first group' do
      #     current_node = find_node('agenda_group_availabilities')
      #     get :run, params: {id: current_node.id}
      #
      #     current_node = find_node('appointment_menu1')
      #     expect(ask_say).to eq group_text(current_node, {day: 'today', start: '09:30 AM', finish: '05:00 PM', num: 1})
      #     expect(next_url).to eq next_node_path('appointment_menu1', response: true)
      #   end
      #
      #   it 'repeats on asterisk' do
      #     find_node('agenda_group_availabilities').run
      #     current_node = find_node('appointment_menu1')
      #     get :run, params: {id: current_node.id, parse_response: true, test_input: '*'}
      #     expect(ask_say).to eq group_text(current_node, {day: 'today', start: '09:30 AM', finish: '05:00 PM', num: 1})
      #     # expect(ask_say).to eq 'Press 1 today between 09:30 AM and 06:00 PM. To repeat, press 9. Or wait to hear more availabilities.'
      #   end
      #
      #   it 'offers next group on timeout' do
      #     find_node('agenda_group_availabilities').run
      #     current_node = find_node('appointment_menu1')
      #     get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}
      #     current_node = find_node('appointment_menu2')
      #     expect(ask_say).to eq group_text(current_node, {day: 'tomorrow', start: '08:00 AM', finish: '05:00 PM', num: 1},
      #                                      {day: 'Wednesday, 25th of April', start: '08:00 AM', finish: '05:00 PM', num: 2})
      #   end
      #
      #   it 'selects first group' do
      #     find_node('agenda_group_availabilities').run
      #     current_node = find_node('appointment_menu1')
      #     get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
      #     expect(data[:group1_date]).to eq data[:choosen_group]
      #     current_node = find_node('appointment_menu3')
      #     expect(ask_say).to eq menu1_text(current_node, slot1: '08:00 AM', slot2: '08:30 AM', slot3: '09:00 AM')
      #   end
      #
      #   context 'no slots available' do
      #     let(:test_time){Time.zone.local(2018, 06, 11, 9, 00)}
      #     it 'should say not found message if no slot is found' do
      #       find_node('agenda_group_availabilities').run
      #       current_node = find_node('appointment_menu1')
      #
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
      #       expect(data[:group1_date]).to eq data[:choosen_group]
      #       expect(data[:slot_count]).to eq 3
      #
      #       #  last slot of day
      #       data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #       current_node = find_node('agenda_slot_availabilities')
      #       get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #       expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
      #     end
      #
      #     it 'should say not found message after last two slots' do
      #       find_node('agenda_group_availabilities').run
      #       current_node = find_node('appointment_menu1')
      #
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
      #       expect(data[:group1_date]).to eq data[:choosen_group]
      #
      #       data[:slot3_start] = Time.zone.parse('2018-06-11T16:00')
      #       current_node = find_node('agenda_slot_availabilities')
      #       get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #       # expect(ask_say).to eq 'Press 1 for 04:30 PM. Press 2 for 05:00 PM. Wait to hear next availabilities. Or press 9 to repeat.'
      #
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}
      #       expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
      #     end
      #
      #     it 'should repeat slots' do
      #       find_node('agenda_group_availabilities').run
      #       current_node = find_node('appointment_menu1')
      #
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
      #       expect(data[:group1_date]).to eq data[:choosen_group]
      #       expect(data[:slot_count]).to eq 3
      #
      #       #  last slot of day
      #       data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #       current_node = find_node('agenda_slot_availabilities')
      #       get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #       # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
      #
      #       current_node = find_node('no_slot_found_for_menu2')
      #       get :run, params: {id: current_node.id, test_input: 1, parse_response: true}
      #       current_node = find_node('appointment_menu3')
      #       expect(ask_say).to eq menu1_text(current_node, slot1: '08:00 AM', slot2: '08:30 AM', slot3: '09:00 AM')
      #       # expect(ask_say).to eq '<speak>For 08:00 AM, press 1. <break time=\"400ms\"/>  For 08:30 AM, press 2. <break time=\"400ms\"/...s 9 to repeat these availabilities. Or <emphasis>Hold</emphasis> the line for more options.</speak>'
      #     end
      #
      #     it 'should ask for next group' do
      #       find_node('agenda_group_availabilities').run
      #       current_node = find_node('appointment_menu1')
      #
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
      #       expect(data[:group1_date]).to eq data[:choosen_group]
      #       expect(data[:slot_count]).to eq 3
      #
      #       #  last slot of day
      #       data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #       current_node = find_node('agenda_slot_availabilities')
      #       get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #       # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
      #
      #       current_node = find_node('no_slot_found_for_menu2')
      #       get :run, params: {id: current_node.id, test_input: 2, parse_response: true}
      #       current_node = find_node('appointment_menu2')
      #       expect(ask_say).to eq group_text(current_node, {day: 'tomorrow', start: '08:00 AM', finish: '05:00 PM', num: 1},
      #                                        {day: 'Wednesday, 13th of June', start: '08:00 AM', finish: '05:00 PM', num: 2})
      #         # expect(ask_say).to eq '<speak>For tomorrow, between &lt; 08:00 AM, and, 05:00 PM, press 1. <break time=\"400ms\"/> For Wedn...is>next availabilities</emphasis>. Or <emphasis>press 9</emphasis> to repeat these options.</speak>'
      #     end
      #
      #     it 'should ask for next group if user selected second group' do
      #       find_node('agenda_group_availabilities').run
      #       current_node = find_node('appointment_menu1')
      #
      #       # on timeout fetch next group
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}
      #       expect(data[:choosen_group]).to eq nil
      #
      #       # select second group now
      #       current_node = find_node('appointment_menu2')
      #       get :run, params: {id: current_node.id, parse_response: true, test_input: 2}
      #       expect(data[:choosen_group]).to eq data[:group2_date]
      #
      #       expect(data[:slot_count]).to eq 3
      #
      #       #  last slot of day
      #       data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #       current_node = find_node('agenda_slot_availabilities')
      #       get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #       # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
      #
      #       current_node = find_node('no_slot_found_for_menu2')
      #       get :run, params: {id: current_node.id, test_input: 2, parse_response: true}
      #
      #       current_node = find_node('appointment_menu2')
      #       expect(ask_say).to eq group_text(current_node, {day: 'Thursday, 14th of June', start: '08:00 AM', finish: '05:00 PM', num: 1},
      #                                        {day: 'Friday, 15th of June', start: '08:00 AM', finish: '05:00 PM', num: 2})
      #
      #     end
      #
      #     context 'menu 4 - search by constraints' do
      #       it 'should repeat' do
      #         current_node = find_node('search_by_date')
      #         get :run, params: {id: current_node.id, parse_response: true, test_input: '20180611'}
      #         # expect(ask_say).to eq 'Press 1 for 08:00 AM. Press 2 for 08:30 AM. Press 3 for 09:00 AM. Wait to hear next availabilities. Or press 9 to repeat.'
      #
      #         #  last slot of day
      #         data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #         current_node = find_node('agenda_slot_availabilities')
      #         get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #         puts response.body
      #         # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu4_no_slot_found')
      #
      #         current_node = find_node('no_slot_found_for_menu4')
      #         get :run, params: {id: current_node.id, test_input: 1, parse_response: true}
      #         current_node = find_node('appointment_menu3')
      #         expect(ask_say).to eq menu1_text(current_node, slot1: '08:00 AM', slot2: '08:30 AM', slot3: '09:00 AM')
      #         # expect(ask_say).to eq '<speak>For 08:00 AM, press 1. <break time=\"400ms\"/>  For 08:30 AM, press 2. <break time=\"400ms\"/...s 9 to repeat these availabilities. Or <emphasis>Hold</emphasis> the line for more options.</speak>'
      #       end
      #
      #       it 'should ask for another date' do
      #         current_node = find_node('search_by_date')
      #         get :run, params: {id: current_node.id, parse_response: true, test_input: '20180611'}
      #         # expect(ask_say).to eq 'Press 1 for 08:00 AM. Press 2 for 08:30 AM. Press 3 for 09:00 AM. Wait to hear next availabilities. Or press 9 to repeat.'
      #
      #         #  last slot of day
      #         data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #         current_node = find_node('agenda_slot_availabilities')
      #         current_node = get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #         puts response.body
      #         # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu4_no_slot_found')
      #
      #         current_node = find_node('no_slot_found_for_menu4')
      #         response = get :run, params: {id: current_node.id, test_input: 2, parse_response: true}
      #         expect(ask_say).to eq 'Please enter a date, followed by the hash key. '
      #       end
      #
      #       it 'should search by ampmafter asking preferences' do
      #         current_node = find_node('search_by_date')
      #         get :run, params: {id: current_node.id, parse_response: true, test_input: '20180611'}
      #         # expect(ask_say).to eq 'Press 1 for 08:00 AM. Press 2 for 08:30 AM. Press 3 for 09:00 AM. Wait to hear next availabilities. Or press 9 to repeat.'
      #
      #         #  last slot of day
      #         data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #         current_node = find_node('agenda_slot_availabilities')
      #         current_node = get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #         puts response.body
      #         # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu4_no_slot_found')
      #
      #         current_node = find_node('no_slot_found_for_menu4')
      #         get :run, params: {id: current_node.id, test_input: 3, parse_response: true}
      #         # expect(ask_say).to eq 'To search by date, press 1. To search by weekday, press 2. To search by AM/PM, press 3. To search by time, press 4'
      #
      #         current_node = find_node('appointment_menu4')
      #         # press 3 to serach by am/pm
      #         get :run, params: {id: current_node.id, test_input: 3, parse_response: true}
      #         # press 3
      #         # expect(ask_say).to eq 'Press 1 for A.M press 2 for P.M'
      #
      #         current_node = find_node('search_by_ampm')
      #         # press 2 for pm
      #         get :run, params: {id: current_node.id, test_input: 2, parse_response: true}
      #         current_node = find_node('appointment_menu3')
      #         expect(ask_say).to eq menu1_text(current_node, slot1: 'Tuesday, 12th of June at 12:00 PM', slot2: 'Tuesday, 12th of June at 12:30 PM')
      #       end
      #
      #       it 'should search by time slot after asking preferences' do
      #         current_node = find_node('search_by_date')
      #         get :run, params: {id: current_node.id, parse_response: true, test_input: '20180611'}
      #         # expect(ask_say).to eq 'Press 1 for 08:00 AM. Press 2 for 08:30 AM. Press 3 for 09:00 AM. Wait to hear next availabilities. Or press 9 to repeat.'
      #
      #         #  last slot of day
      #         data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
      #         current_node = find_node('agenda_slot_availabilities')
      #         current_node = get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
      #         puts response.body
      #         # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu4_no_slot_found')
      #
      #         current_node = find_node('no_slot_found_for_menu4')
      #         get :run, params: {id: current_node.id, test_input: 3, parse_response: true}
      #         # expect(ask_say).to eq 'To search by date, press 1. To search by weekday, press 2. To search by AM/PM, press 3. To search by time, press 4'
      #
      #         current_node = find_node('appointment_menu4')
      #         # press 4 to serach by time slot
      #         get :run, params: {id: current_node.id, test_input: 4, parse_response: true}
      #
      #         current_node = find_node('search_by_time')
      #         get :run, params: {id: current_node.id, test_input: '1215', parse_response: true}
      #         current_node = find_node('appointment_menu3')
      #         expect(ask_say).to eq menu1_text(current_node, slot1: 'Tuesday, 12th of June at 12:00 PM', slot2: 'Tuesday, 12th of June at 12:30 PM')
      #         # expect(ask_say).to eq '<speak>For Tuesday, 12th of June at 12:00 PM, press 1. <break time=\"400ms\"/>  For Tuesday, 12th of...s 9 to repeat these availabilities. Or <emphasis>Hold</emphasis> the line for more options.</speak>'
      #       end
      #     end
      #   end
      # end


      context 'timify', vcr: { cassette_name: 'timify_availabilities'}  do
        let(:test_time){Time.zone.local(2018, 9, 24, 9, 00)}
        let(:agenda_app) {
          Timify.create(timify_access_token: ENV['TIMIFY_ACCESS_TOKEN'], timify_company_id: ENV['TIMIFY_TEST_COMPANY_ID'], ivr: ivr, client: ivr.client)
        }

        before do
          data[:choosen_service] = '5d9f2ac56d95c0112ca1ccab'
        end

        describe 'customers' do
          let(:current_node) {find_node('gather_number')}
          let(:test_time) {Time.zone.local(2018, 9, 24, 9, 00)}

          context 'client allows new users' do
            before {data[:ivr_preference_allow_new_customers] = true}
            it 'should save phone number and continue' do
              get :run, params: {id: next_node, test_input: '923215112233', parse_response: true}
              expect(saved_data(:gather_number)).to eq '923215112233'
              expect(ask_say).to eq t('static_ivr.menu_closed')
              # expect(current_call.reload.client_type).to eq 'new'
            end

            describe 'record user name' do
              let(:current_node) { find_node('record_user_name') }
              it 'creates a new customer' do
                allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
                allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})
                expect do
                  get :run, params: {id: next_node, test_input: 'Shan', uid: '32470123456', parse_response: true}
                end.to change{ Customer.count }.by(0)
                expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
              end
            end
          end

          context 'client does not allow new users' do
            let(:current_node) { find_node('check_existing_caller') }
            it 'should forward call' do
              get :run, params: {id: next_node, test_input: '3215112233', parse_response: true}
              expect(say).to eq t('static_ivr.new_customer_not_allowed')
            end
          end

          context 'caller already exist on Agenda' do
            before do
              client.update(country: 'IN')
            end
            it 'should allow to enter bot' do
              get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
              expect(current_call.reload.client_type).to eq 'returning'
            end

            context 'create appointment with customer' do
              before do
                data[:choosen_service] = '5d9f2ac56d95c0112ca1ccab'
              end

              it 'should create an appointment' do
                get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
                create_appointment
              end
            end

            # https://api.mobminder.com/query/visiapps.php?lgn=voxy&pwd=laura&kid=19102&id=4928866&web=1
            context 'create appointment with specific customer' do
              let(:test_time){Time.zone.local(2019, 04, 25, 10, 00)}

              before do
                data[:choosen_resource] = '5d9f2a7b6d95c0112ca1cc91' # axel
                data[:choosen_service] = '5d9f2ac56d95c0112ca1ccab' # setup
              end
              it 'should create appointment' do
                # {"resource_id"=>"5d9f2a7b6d95c0112ca1cc91", "service_id"=>"5d9f2ac56d95c0112ca1ccab", "datetime"=>Thu, 18 Apr 2019 10:00:00 +0000, "duration"=>15, :customer_id=>"5b7517f29866aa0c398cb5c4"}
                get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
                # create_appointment
                current_node = find_node('agenda_group_availabilities')
                find_node('agenda_group_availabilities').run

                current_node = find_node('appointment_menu1')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('appointment_menu3')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('confirm_create')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
                expect(say).to match(t('static_ivr.internal_error'))
              end

              it 'should say existing appointments', vcr: true do
                data[:choosen_resource] = nil
                data[:choosen_service] = nil
                data[:ivr_preference_max_allowed_appointments] = 1
                data[:ivr_preference_allow_cancel_or_modify] = true
                current_node = find_node('gather_number')
                @resp = get :run, params: {id: current_node.id, test_input: '919770555563', parse_response: true}
                @resp = get :run, params: {id: find_node('check_existing_caller').id}
                current_node = find_node('get_existing_appointments')
                ivr.preference['cancel_time_offset'] = "%{1_minutes}"
                ivr.save
                ivr.update_column :preference, ivr.preference
                ivr.reload
                @resp = get :run, params: {id: current_node}
                # if limit is reached won't say Press 3 to create
                # To modify an appointment press 1. To delete an appointment press 2. Or press 9 to repeat.
                # expect(ask_say).to match('You already have a confirmed appointment')
                expect(ask_say).to be_nil

                current_node = find_node('cmd_menu')

                @resp = get :run, params: {id: current_node, parse_response: true, test_input: 1} # modify

                current_node = find_node('appointment_menu1')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('appointment_menu3')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('confirm_create')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

              end
            end
          end

          context 'a valid user name is provided' do
            before do
              data[:caller_id] = '919770555563'
            end
            it 'should allow to enter bot' do
              allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
              allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})

              current_node = find_node('record_user_name')
              current_node.ivr.preference['say_recorded_name'] = true
              current_node.ivr.save

              get :run, params: {id: current_node, test_input: 'Shan', parse_response: true}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
            end
          end
        end


        let(:current_node) {find_node('agenda_group_availabilities')}
        it 'gets availabilities' do
          get :run, params: {id: current_node.id}

          current_node = find_node('appointment_menu1')
          # expect(ask_say).to eq group_text(current_node, { day: 'today', start: '10:00 AM', finish: '05:45 PM', num: 1 })
          # expect(ask_say).to eq t('static_ivr.appointment_group_menu.other')
          expect(ask_say).to be_nil
          # expect(next_url).to eq next_node_path('appointment_menu1', response: true)
        end

        it 'says next availabilities on timeout/wait' do
          find_node('agenda_group_availabilities').run
          get :run, params: {id: current_node.id}
          current_node = find_node('appointment_menu1')

          get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
          expect(data[:group1_date]).to eq data[:choosen_group]
          # expect(data[:slot_count]).to eq 3
          expect(data[:slot_count]).to be_nil
          # expect(ask_say).to eq 'Press 1 for 10:00 AM. Press 2 for 10:15 AM. Press 3 for 10:30 AM. Wait to hear next availabilities. Or press 9 to repeat.'

          current_node = find_node('appointment_menu3')
          get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}

          current_node = find_node('appointment_menu3')
          expect(ask_say).to be_nil
          # expect(ask_say).to eq menu1_text(current_node, slot1: '10:45 AM', slot2: '11:00 AM', slot3: '11:15 AM')

          # expect(ask_say).to eq '<speak>For 10:45 AM, press 1. <break time=\"400ms\"/>  For 11:00 AM, press 2. <break time=\"400ms\"/...s 9 to repeat these availabilities. Or <emphasis>Hold</emphasis> the line for more options.</speak>'

          # #  last slot of day
          # data[:slot3_start] = Time.zone.parse('2018-06-11T18:00')
          # current_node = find_node('agenda_slot_availabilities')
          # get :run, params: {id: current_node.id, test_input: 'TIMEOUT'}
          # expect(ask_say).to eq I18n.t('static_ivr.appointment_group_menu2_no_slot_found')
        end

        describe 'services' do
          # let(:current_node) {find_node('agenda_services')}
          it 'gets all services from agenda' do
            current_node = find_node('agenda_services')
            # skip 'Now only enabled are offered'
            get :run, params: {id: current_node.id}
            current_node = find_node('appointment_menu1')
            # expect(ask_say).to eq group_text(current_node,{ day: 'today', start: '10:00 AM', finish: '05:45 PM', num: 1 })
            # expect(ask_say).to eq t('static_ivr.appointment_group_menu.other')
            expect(ask_say).to be_nil
          end

          it 'gets services from local db', vcr: true do
            current_node = find_node('agenda_services')
            agenda_app.configure_services(['5d9f2ac56d95c0112ca1ccab'], random_resource: false)
            agenda_app.configure_resources(['5d9f2a7b6d95c0112ca1cc91'],
                                           service_id: '5d9f2ac56d95c0112ca1ccab',
                                           random_resource: false) # Axel, Ruba
            get :run, params: {id: current_node.id}

            current_node = find_node('select_resource')
            # expect(ask_say).to eq resource_text(['Axel', 'Ruba']) #'For Axel, press 1. For Ruba, press 2.  Or press 9 to repeat.'
            expect(ask_say).to eq t('static_ivr.appointment_group_menu.other')
          end
        end

        describe 'resources' do
          let(:current_node) {find_node('agenda_resources')}
          it 'gets all resources from agenda' do
            skip 'Now only enabled are offered'
            data[:choosen_service] = '5d9f2ac56d95c0112ca1ccab'
            get :run, params: {id: current_node.id}
            current_node = find_node('select_resource')
            expect(ask_say).to eq resource_text(['Voxiplan Contact', 'Axel', 'Ruba']) #'For Axel, press 1. For Ruba, press 2.  Or press 9 to repeat.'
          end

          it 'gets resources from local db', vcr: true do
            agenda_app.configure_resources(['5d9f2a7b6d95c0112ca1cc91'])
            get :run, params: {id: current_node.id}
            puts res.to_yaml
            # expect(ask_say).to eq 'For Setup, press 1. For Support, press 2. For test, press 3.  Or press 9 to repeat.'
          end
        end
      end

      context 'mobminder', vcr: { cassette_name: 'mm_availabilities'} do
        let(:test_time){Time.zone.local(2019, 1, 21, 9, 00)}

        before do
          data[:choosen_resource] = '13137'
          data[:choosen_service] = '16986'
        end

        let(:agenda_app) {
          Mobminder.create(mm_login: ENV['MM_LOGIN'], mm_pwd: ENV['MM_PASSWORD'], mm_kid: ENV['MM_KEY'], ivr: ivr, client: ivr.client)
        }

        describe 'customers' do
          let(:current_node) {find_node('gather_number')}
          let(:test_time) {Time.zone.local(2018, 12, 31, 9, 00)}

          context 'client allows new users' do
            before {data[:ivr_preference_allow_new_customers] = true}
            it 'should save phone number and continue' do
              get :run, params: {id: next_node, test_input: '923215112233', parse_response: true}
              expect(saved_data(:gather_number)).to eq '923215112233'
              @resp = get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.new_customer_enter_your_name')
            end

            describe 'record user name' do
              let(:current_node) { find_node('record_user_name') }
              it 'creates a new customer' do
                allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
                allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'Sheikh', gender: 'm'})
                allow(SecureRandom).to receive(:hex).and_return '123456'

                current_node.ivr.preference['say_recorded_name'] = true
                expect do
                  get :run, params: {id: next_node, test_input: 'Shan', parse_response: true, uid: '32470123456'}
                end.to change{ Customer.count }.by(1)
                expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
              end
            end
          end

          context 'client does not allow new users' do
            it 'should forward call' do
              get :run, params: {id: find_node('check_existing_caller').id, test_input: '3215112233', parse_response: true}
              expect(say).to eq t('static_ivr.new_customer_not_allowed')
            end
          end

          context 'caller already exist on Agenda' do
            before do
              client.update(country: 'FR')
            end
            it 'should allow to enter bot' do
              get :run, params: {id: next_node, test_input: '33493655599', parse_response: true}
              @resp =  get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Pascal')
            end

            context 'create appointment with specific customer' do
              before do
                data[:choosen_resource] = '13138'
                data[:choosen_service] = '16986'
              end
              it 'should create appointment' do
                allow_any_instance_of(Mobminder).to receive(:all_resources).and_return({:uCals=>"13138", :bCals=>"6978"})
                get :run, params: {id: next_node, test_input: '33493655599', parse_response: true}
                @resp = get :run, params: {id: find_node('check_existing_caller').id}
                create_appointment
              end
            end

            # https://api.mobminder.com/query/visiapps.php?lgn=voxy&pwd=laura&kid=19102&id=4928866&web=1
            context 'create appointment with specific customer' do
              let(:test_time){Time.zone.local(2019, 05, 20, 10, 00)}

              before do
                data[:choosen_resource] = '13138'
                data[:choosen_service] = '16986'
              end
              it 'should create appointment' do
                get :run, params: {id: next_node, test_input: '32470123456', parse_response: true}
                @resp = get :run, params: {id: find_node('check_existing_caller').id}
                # create_appointment
                current_node = find_node('agenda_group_availabilities')
                find_node('agenda_group_availabilities').run
                @resp = get :run, params: {id: current_node.id}

                current_node = find_node('appointment_menu1')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('confirm_create')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
                # expect(say).to match(/Thank you/)
                expect(say).to match(t('static_ivr.internal_error'))
              end

              it 'should say existing appointments' do
                data[:ivr_preference_max_allowed_appointments] = 1
                data[:ivr_preference_allow_cancel_or_modify] = true
                current_node = find_node('gather_number')
                @resp = get :run, params: {id: current_node.id, test_input: '32470123456', parse_response: true}
                @resp = get :run, params: {id: find_node('check_existing_caller').id}

                current_node = find_node('get_existing_appointments')
                ivr.preference['cancel_time_offset'] = "%{1_minutes}"
                ivr.save
                ivr.update_column :preference, ivr.preference
                ivr.reload
                @resp = get :run, params: {id: current_node}
                # if limit is reached won't say Press 3 to create
                # To modify an appointment press 1. To delete an appointment press 2. Or press 9 to repeat.
                expect(ask_say).to match('You already have a confirmed appointment')

                current_node = find_node('cmd_menu')

                @resp = get :run, params: {id: current_node, parse_response: true, test_input: 1} # make changes to existing
                # offers dates
                # expect(ask_say).to match('To confirm your choice')

                # current_node = find_node('confirm_modify')
                # @resp = get :run, params: {id: current_node, parse_response: true, test_input: 1}
                # expect(data[:choosen_resource]).to_not be_nil

                current_node = find_node('appointment_menu1')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('appointment_menu3')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

                current_node = find_node('confirm_create')
                @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
                expect(say).to match(t('static_ivr.internal_error'))
              end
            end
          end

          context 'a valid user name is provided' do
            before do
              data[:caller_id] = '919770555563'
            end
            it 'should allow to enter bot' do
              allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
              allow(SecureRandom).to receive(:hex).and_return '123456'
              allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'Sheikh', gender: 'm'})

              current_node = find_node('record_user_name')
              get :run, params: {id: current_node, test_input: 'Shan', parse_response: true}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
            end
          end
        end


        describe 'Existing appoitnments' do
          it 'should get appointments after announcement' do
            current_node = find_node('appointment_announcement_closed')
            # get :run, params: {id: current_node, test_input: '33493655599', parse_response: true}
            get :run, params: {id: current_node}
            expect(say).to eq t('static_ivr.appointment_announcement_closed')
            expect(next_url).to eq next_node_path('get_existing_appointments')
          end

          context 'client alrady have appointments' do
            before do
              client.update(country: 'FR')
              data[:ivr_preference_max_allowed_appointments] = 1
            end

            it 'should say existing appointments' do
              data[:ivr_preference_allow_cancel_or_modify] = true
              current_node = find_node('gather_number')
              get :run, params: {id: current_node.id, test_input: '33493655599', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              current_node = find_node('get_existing_appointments')
              get :run, params: {id: current_node}
              # if limit is reached won't say Press 3 to create
              # To modify an appointment press 1. To delete an appointment press 2. Or press 9 to repeat.
              # expect(ask_say).to eq t('static_ivr.create_modify_delete_menu')
              current_node = find_node('cmd_menu')
              get :run, params: {id: current_node, parse_response: true, test_input: 1} # modify
              # To modify appointment for Monday, 31st of December at 10:15 AM, press 1.  Or press 9 to repeat.

              get :run, params: {id: current_node, parse_response: true, test_input: 3} # create
              # expect(ask_say).to eq "Press 1 today between 10:00 AM and 08:00 PM. To repeat, press 9. Or wait to hear more availabilities."

              get :run, params: {id: current_node, parse_response: true, test_input: 2} # cancel
              # expect(ask_say).to eq 'To cancel appointment for Monday, 31st of December at 10:15 AM, press 1.  Or press 9 to repeat.'

              current_node = find_node('cancel_menu')
              get :run, params: {id: current_node, parse_response: true, test_input: 1}
              # expect(say).to eq "Your appointment is cancelled successfully. "
              #
              expect(say).to eq t('static_ivr.cancel_time_limit_reached')

              current_node = find_node('modify_menu')
              get :run, params: {id: current_node, parse_response: true, test_input: 1}
            end

            it 'should allow to direclty cancel if there is just one appointment and time limit is not reached' do
              allow_any_instance_of(Mobminder).to receive(:existing_appointments) do |obj, processor|
                [{"id"=>"9352098", "time"=>Time.parse('Mon, 31 Dec 2018 13:30:00 +0000')}]
              end

              data[:ivr_preference_allow_cancel_or_modify] = true
              current_node = find_node('gather_number')
              get :run, params: {id: current_node.id, test_input: '33493655599', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              current_node = find_node('get_existing_appointments')
              get :run, params: {id: current_node}

              current_node = find_node('cmd_menu')
              @resp = get :run, params: {id: current_node, parse_response: true, test_input: 2}
              #         expect(ask_say.strip).to eq t('static_ivr.appointment_cofirmation')
              expect(ask_say).to be_nil

              current_node = find_node('confirm_cancel')
              @resp = get :run, params: {id: current_node, parse_response: true, test_input: 1}
              expect(say).to eq t('static_ivr.internal_error', customer_first_name: 'Pascal')
              expect(current_call.reload.appointment_type).to eq 'cancelled'
            end
          end
        end

        it 'gets availabilities' do
          current_node = find_node('agenda_group_availabilities')
          get :run, params: {id: current_node.id}

          current_node = find_node('appointment_menu1')
          expect(ask_say).to eq group_text(current_node, { day: 'tomorrow', start: '10:00 AM', finish: '08:30 PM', num: 1 })
          expect(next_url).to eq next_node_path('appointment_menu1', response: true)
        end

        context 'time frame has only one slot' do
          it 'say time directly' do
            data[:customer_first_name] = 'Axel'
            allow_any_instance_of(Mobminder).to receive(:free_slots) do |obj, p1, p2 ,p3|
              [{"start"=>Time.zone.parse('Tue, 22 Jan 2019 10:00:00 PKT +05:00'), "finish"=>Time.zone.parse('Tue, 22 Jan 2019 10:30:00 PKT +05:00'), "service_id"=>"16986", "resource_id"=>"13137", "uCals"=>"13137", "bCals"=>"6978"}]
            end

            current_node = find_node('agenda_group_availabilities')
            get :run, params: {id: current_node.id}

            current_node = find_node('appointment_menu1')
            # expect(ask_say).to eq group_text(current_node, {day: 'today', time: '10:00 AM', num: 1, count: 1})
            # expect(next_url).to eq next_node_path('appointment_menu1', response: true)

            get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}

            get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

            current_node = find_node('confirm_create')
            get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

            current_node = find_node('appointment_success')
            # expect(say).to eq current_node.text % {choosen_slot_start: 'Tuesday, 22nd of January at 10:00 AM', customer_first_name: 'Axel'}
            expect(say).to eq t('static_ivr.internal_error')
          end
        end

        describe 'toboxing', vcr: { cassette_name: 'mm_tboxing'} do
          let(:test_time){Time.zone.local(2023, 12, 8, 9, 00)}
          before do
            data[:choosen_resource] = '13138'
            data[:choosen_service] = '15414'
          end

          it 'gets other availabilities' do
            allow_any_instance_of(Mobminder).to receive(:all_resources).and_return( {:uCals=>"13138", :bCals=>"6978"})
            current_node = find_node('agenda_group_availabilities')
            @resp = get :run, params: {id: current_node.id}

            current_node = find_node('appointment_menu1')
            @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}
            current_node = find_node('appointment_menu2')

            expect(ask_say).to eq group_text(current_node, {day: 'Saturday, 16th of December', start: '04:00 PM', finish: '04:30 PM', num: 1, count: 2},
                                             {day: 'Saturday, 23rd of December', start: '04:00 PM', finish: '04:30 PM', num: 2, count: 2})
          end
        end

        describe 'initial delay' do
          let(:test_time){Time.zone.local(2019, 1, 23, 9, 00)}

          it 'gets availabilities after x time' do
            current_node = find_node('agenda_group_availabilities')
            current_node.parameters['after_time'] = '%{2_hours}'
            current_node.save
            get :run, params: {id: current_node.id}

            current_node = find_node('appointment_menu1')
            expect(ask_say).to eq group_text(current_node, { day: 'today', start: '12:00 PM', finish: '12:30 PM', num: 1 })
            expect(next_url).to eq next_node_path('appointment_menu1', response: true)
          end
        end

        it 'says next availabilities on timeout/wait' do
          current_node = find_node('agenda_group_availabilities')

          find_node('agenda_group_availabilities').run
          get :run, params: {id: current_node.id}
          current_node = find_node('appointment_menu1')

          get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
          expect(data[:group1_date]).to eq data[:choosen_group]
          expect(data[:slot_count]).to eq 3
          # expect(ask_say).to eq 'Press 1 for 10:00 AM. Press 2 for 10:15 AM. Press 3 for 10:30 AM. Wait to hear next availabilities. Or press 9 to repeat.'

          current_node = find_node('appointment_menu3')
          get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}
          # current_node = find_node('appointment_menu3')
          expect(ask_say).to eq menu1_text(current_node, slot1: '08:00 PM', slot2: '08:15 PM', slot3: '08:30 PM')
        end

        it 'should repeat on press 9' do
          find_node('agenda_group_availabilities').run
          current_node = find_node('appointment_menu1')
          get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
          current_node = find_node('appointment_menu3')
          get :run, params: {id: current_node.id, parse_response: true, test_input: '9'}
          expect(ask_say).to eq menu1_text(current_node, slot1: '10:00 AM', slot2: '07:30 PM', slot3: '07:45 PM')
          # expect(ask_say).to eq 'For 10:00 AM, press 1. 07:30 PM, press 2. 07:45 PM, press 3. Wait to hear next availabilities. Or press 9 to repeat.'
        end

        describe 'services' do
          #let(:current_node) {find_node('agenda_services')}
          it 'gets all services from agenda' do
            current_node = find_node('agenda_services')
            #skip 'Now only enabled are offered'
            get :run, params: {id: current_node.id}
            current_node = find_node('appointment_menu1')
            # expect(ask_say).to eq group_text(current_node, { day: 'tomorrow', start: '10:00 AM', finish: '08:30 PM', num: 1 })
            expect(ask_say).to be_nil
          end

          it 'gets services from local db' do
            current_node = find_node('agenda_services')
            agenda_app.configure_resources(['13137'])
            agenda_app.configure_services(['15649', '15650'], resource_id: agenda_app.ivr.resources.first.eid)
            get :run, params: {id: current_node.id}
            current_node = find_node('appointment_menu1')
            # expect(ask_say).to eq service_text(['Test service 3', 'Test service 4']) #'For Axel, press 1. For Ruba, press 2.  Or press 9 to repeat.'
            # expect(ask_say).to eq '<speak>For Test service 3, press 1. <break time=\"400ms\"/> For Test service 4, press 2. <break time=\"400ms\"/>  Or press 9 to repeat these options.</speak>'
            expect(ask_say).to eq group_text(current_node, { day: 'tomorrow', start: '10:00 AM', finish: '08:30 PM', num: 1 })
          end
        end

        describe 'resources' do
          before do
            data[:choosen_resource] = nil
            data[:choosen_service] = '15650'
          end

          #let(:current_node) {find_node('agenda_resources')}
          it 'gets all resources from agenda' do
            current_node = find_node('agenda_resources')
            skip 'Now only enabled are offered'
            get :run, params: {id: current_node.id}
            expect(ask_say).to eq 'For Olivier, press 1. For Usman, press 2. For Shankar, press 3. For Test, press 4.  Or press 9 to repeat.'
          end

          it 'gets resources from local db' do
            current_node = find_node('agenda_resources')
            data[:choosen_service] = '15648'
            agenda_app.configure_resources(['13137', '13138', '13139'], service_id: '15648', random_resource: false)
            get :run, params: {id: current_node.id}
            expect(ask_say).to eq resource_text(['Ruba', 'Axel', 'Radio'])
            # expect(ask_say).to eq 'For Ruba, press 1. ...400ms  For Axel, press 2. ...400ms  For Radio, press 3. ...400ms   Or press 9 to repeat these options.'
          end
        end

        describe 'create appointment' do
          before do
            data[:choosen_resource] = '6978'
          end

          it 'should create an appointment' do
            expect(current_call.call_type).to eq 'incoming'
            create_appointment
            expect(current_call.reload.appointment_type).to be_nil
          end
        end
      end


      context 'ClassicAgenda', vcr: { cassette_name: 'cronofy'}  do
        let(:clean_dummy_agenda) do
          DummyAgenda.destroy_all
        end
        let(:test_time){Time.zone.local(2019, 04, 23, 9, 00)}
        let(:agenda_app) {
          ClassicAgenda.create(
              cronofy_access_token: ENV['CRONOFY_ACCESS_TOKEN'],
              cronofy_refresh_token: ENV['CRONOFY_REFRESH_TOKEN'],
              cronofy_profile_id: ENV['CRONOFY_PROFILE_ID'],
              ivr: ivr,
              client: ivr.client,
              default_resource_calendar: 'cal_XINva9B2PhfuWCFH_DwWD9i7M4LrXM-pbHFxsOQ')
        }

        before do
          data[:choosen_service] = client.default_service.id #Resource.where(name: 'Default').eid
          data[:choosen_resource] = client.default_resource.id #Resource.where(name: 'Default').eid
        end

        describe 'customers' do
          let(:current_node) {find_node('gather_number')}

          context 'client allows new users' do
            before {data[:ivr_preference_allow_new_customers] = true}
            it 'should save phone number and continue' do
              get :run, params: {id: next_node, test_input: '923215112233', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(saved_data(:gather_number)).to eq '923215112233'
              expect(say).to eq t('static_ivr.new_customer_enter_your_name')
              expect(current_call.reload.client_type).to eq 'new'
            end

            describe 'record user name' do
              let(:current_node) { find_node('record_user_name') }
              it 'creates a new customer' do
                allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
                allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})
                expect do
                  get :run, params: {id: next_node, test_input: 'Shan', parse_response: true, uid: '32470123456'}
                end.to change{ Customer.count }.by(1)
                expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
              end
            end
          end

          context 'client does not allow new users' do
            it 'should forward call' do
              get :run, params: {id: next_node, test_input: '3215112233', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.new_customer_not_allowed')
            end
          end

          context 'caller already exist on Agenda' do
            before do
              client.update(country: 'IN')
              c = client.customers.create(first_name: 'A', last_name: 'B', phone_number: '919770555563')
              c.update_column :eid, c.id
            end
            it 'should allow to enter bot' do
              get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.new_customer_not_allowed', customer_first_name: 'A')
              expect(current_call.reload.client_type).to eq 'new'
            end

            context 'create appointment with customer', vcr: true do

              it 'should create an appointment' do
                allow(SecureRandom).to receive(:hex).and_return 'test001'
                get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
                get :run, params: {id: find_node('check_existing_caller').id}
                create_appointment
              end
            end
          end

          context 'a valid user name is provided' do
            before do
              data[:caller_id] = '919770555563'
            end
            it 'should allow to enter bot' do
              allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
              allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})

              current_node = find_node('record_user_name')
              current_node.ivr.preference['say_recorded_name'] = true
              current_node.ivr.save

              get :run, params: {id: current_node, test_input: 'Shan', parse_response: true}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
            end
          end
        end

        let(:current_node) {find_node('agenda_group_availabilities')}
        it 'gets availabilities' do
          get :run, params: {id: current_node.id}

          current_node = find_node('appointment_menu1')
          expect(ask_say).to eq(group_text(current_node, { day: 'today', start: '09:15 AM', finish: '04:45 PM', num: 1 })).or be_nil
          # expect(next_url).to eq next_node_path('appointment_menu1', response: true)
        end

        it 'says next availabilities on timeout/wait' do
          find_node('agenda_group_availabilities').run
          @resp = get :run, params: {id: current_node.id}
          current_node = find_node('appointment_menu1')

          @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
          expect(data[:group1_date]).to eq data[:choosen_group]
          expect(data[:slot_count]).to eq(3).or be_nil
          current_node = find_node('appointment_menu3')
          expect(ask_say).to eq(menu1_text(current_node, slot1: '09:00 AM', slot2: '09:15 AM', slot3: '09:30 AM')).or be_nil

          @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}

          expect(ask_say).to eq(menu1_text(current_node, slot1: '10:00 AM', slot2: '10:15 AM', slot3: '10:30 AM')).or be_nil
        end

        describe 'services' do
          let(:custom_service) {
            client.services.create(name: 'Custom Service', eid: 'Custom Service', enabled: true)
          }

          it 'allow user to select a service' do
            agenda_app.configure_services([client.default_service.id, custom_service.id], resource_id: client.resources.first.id, random_resource: false)
            current_node = find_node('agenda_services')
            @resp = get :run, params: {id: current_node.id}
            # expect(ask_say).to eq service_text(['30 Minute Meeting', 'Custom Service']) #'For Axel, press 1. For Ruba, press 2.  Or press 9 to repeat.'
            expect(ask_say).to be_nil
          end
        end

        describe 'resources' do
          let(:custom_resource) {
            client.resources.create(name: 'Custom Resource', enabled: true)
          }

          it 'gets resources from local db' do
            agenda_app.configure_resources([client.default_resource.id, custom_resource.id],
                                           service_id: client.default_service.id, random_resource: false)
            current_node =  find_node('agenda_resources')
            @resp = get :run, params: {id: current_node.id}
            possible_responses = [resource_text(['test ex', 'Custom Resource']), resource_text(['Custom Resource', 'test ex'])]
            expect(possible_responses).to include(ask_say) #'For Axel, press 1. For Ruba, press 2.  Or press 9 to repeat.'
          end
        end
      end

      context 'Dummy Agenda'  do
        let(:clean_dummy_agenda) { 'nothing' }
        # let(:clean_dummy_agenda) do
        #   puts "********* here "
        # end
        let(:test_time){Time.zone.local(2019, 04, 23, 9, 00)}
        let(:agenda_app) {
          DummyAgenda.create(ivr: ivr, client: ivr.client)
        }

        describe 'customers' do
          let(:current_node) {find_node('gather_number')}

          context 'client allows new users' do
            before {data[:ivr_preference_allow_new_customers] = true}
            it 'should save phone number and continue' do
              get :run, params: {id: next_node, test_input: '923215112233', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(saved_data(:gather_number)).to eq '923215112233'
              expect(say).to eq t('static_ivr.new_customer_enter_your_name')
              expect(current_call.reload.client_type).to eq 'new'
            end

            describe 'record user name' do
              let(:current_node) { find_node('record_user_name') }
              it 'creates a new customer' do
                allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
                allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})
                expect do
                  get :run, params: {id: next_node, test_input: 'Shan', parse_response: true, uid: '32470123456'}
                end.to change{ Customer.count }.by(1)
                expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
              end
            end
          end

          context 'client does not allow new users' do
            it 'should forward call' do
              get :run, params: {id: next_node, test_input: '3215112233', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.new_customer_not_allowed')
            end
          end

          context 'caller already exist on Agenda' do
            before do
              client.update(country: 'IN')
              c = client.customers.create(first_name: 'A', last_name: 'B', phone_number: '919770555563')
              c.update_column :eid, c.id
            end
            it 'should allow to enter bot' do
              get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
              get :run, params: {id: find_node('check_existing_caller').id}
              expect(say).to eq t('static_ivr.new_customer_not_allowed', customer_first_name: 'A')
              expect(current_call.reload.client_type).to eq 'new'
            end

            context 'create appointment with customer' do
              it 'should create an appointment' do
                allow(SecureRandom).to receive(:hex).and_return 'test001'
                get :run, params: {id: next_node, test_input: '919770555563', parse_response: true}
                create_appointment
              end
            end
          end

          context 'a valid user name is provided' do
            before do
              data[:caller_id] = '919770555563'
            end
            it 'should allow to enter bot' do
              allow(GoogleSpeechToText).to receive(:recognise).and_return 'Shan'
              allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({first_name: 'Shan', last_name: 'sheikh', gender: 'm'})

              current_node = find_node('record_user_name')
              current_node.ivr.preference['say_recorded_name'] = true
              current_node.ivr.save

              get :run, params: {id: current_node, test_input: 'Shan', parse_response: true}
              expect(say).to eq t('static_ivr.appointment_announcement_closed', customer_first_name: 'Shan')
            end
          end
        end

        let(:current_node) {find_node('agenda_group_availabilities')}
        it 'gets availabilities' do
          get :run, params: {id: current_node.id}

          current_node = find_node('appointment_menu1')
          # expect(ask_say).to eq group_text(current_node, { day: 'today', start: '09:30 AM', finish: '04:30 PM', num: 1 })
          expect(ask_say).to be_nil
          # expect(next_url).to eq next_node_path('appointment_menu1', response: true)
        end

        it 'says next availabilities on timeout/wait' do
          find_node('agenda_group_availabilities').run
          @resp = get :run, params: {id: current_node.id}
          current_node = find_node('appointment_menu1')

          @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
          expect(data[:group1_date]).to eq data[:choosen_group]
          # expect(data[:slot_count]).to eq 3
          expect(data[:slot_count]).to be_nil
          current_node = find_node('appointment_menu3')
          # expect(ask_say).to eq menu1_text(current_node, slot1: '09:00 AM', slot2: '09:30 AM', slot3: '10:00 AM')
          expect(ask_say).to be_nil

          @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 'TIMEOUT'}

          # expect(ask_say).to eq menu1_text(current_node, slot1: '10:30 AM', slot2: '11:00 AM', slot3: '11:30 AM')
          expect(ask_say).to be_nil
        end
      end

    end

    # No longer valid. We are using Fifo + constraints
    # describe 'fifo - automated' do
    #   before do
    #     ivr.destroy_nodes
    #     ivr.start_node = StaticIvr.new(ivr, scheduling_method: 'fifo').build
    #     ivr.save
    #     ivr.reload
    #   end
    #
    #   let(:current_node) {find_node('agenda_availabilities')}
    #   context 'super_saas', vcr: { cassette_name: 'ss_availabilities'} do
    #     let(:agenda_app) {
    #       SuperSaas.create(ss_schedule_id: SS_SCHEDULE_ID, ss_checksum: SS_CHECKSUM, ivr: ivr)
    #     }
    #
    #     it 'gets first free slots' do
    #       skip "This is a old feature, now we have FiFo + constrains"
    #       get :run, params: {id: current_node.id}
    #       current_node = find_node('appointment_menu3')
    #       expect(ask_say).to eq menu1_text(current_node, slot1: 'Monday, 23rd of April at 09:30 AM')
    #       expect(next_url).to eq next_node_path('appointment_menu1', response: true)
    #     end
    #   end
    # end

  end


end
