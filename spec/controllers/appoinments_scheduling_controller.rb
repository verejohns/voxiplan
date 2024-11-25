require 'rails_helper'

RSpec.describe AppoinmentsSchedulingController, type: :controller do
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

  describe 'Appoinments Scheduling' do
    context 'GET index' do
      it 'should render index page' do
        get :index
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'Appoinments Scheduling' do
    context 'GET announcement' do
      it 'should return appointment_announcement_open appointment_announcement_closed' do
        get :announcement
        expect(response.status).to eq(200)
        expect(assigns(:announcement_open).name).to eq("appointment_announcement_open")
        expect(assigns(:announcement_closed).name).to eq("appointment_announcement_closed")
        expect(assigns(:new_customers_not_allowed).name).to eq("new_customers_not_allowed")
        expect(assigns(:record_user_name).name).to eq("record_user_name")
        expect(response).to render_template("announcement")
      end
    end

    context 'POST announcement' do
      it 'should save opened announcement' do
        open_text = "Hey!! This is announcement for open"
        post :announcement, params: {:announcement => {
                                                        :open => {text: open_text}
                                                      }
                                    }
        expect(response.status).to eq(200)
        expect(assigns(:announcement_open).text).to eq(open_text)
      end

      it 'should save closed announcement' do
        closed_text = "Hey!! This is announcement for open"
        post :announcement, params: {:announcement => {
                                                        :closed => {text: closed_text}
                                                      }
                                    }
        expect(response.status).to eq(200)
        expect(assigns(:announcement_closed).text).to eq(closed_text)
      end

      it 'should save booking access' do
        booking_access_text = "Hey!! This is booking access"
        post :announcement, params: {:announcement => {
                                                      :booking_access => {text: booking_access_text}
                                                    }
                                  }
        expect(response.status).to eq(200)
        expect(assigns(:booking_access).text).to eq(booking_access_text)
      end

      it 'should save booking access' do
        record_user_name_text = "Hey!! This is booking access"
        post :announcement, params: {:announcement => {
                                                      :record_user_name => {text: record_user_name_text}
                                                    }
                                  }
        expect(response.status).to eq(200)
        expect(assigns(:record_user_name).text).to eq(record_user_name_text)
      end

      it 'should save record user name' do
        text = "Hey!! This is booking access"
        post :announcement, params: {:announcement => {
                                                      :new_customers_not_allowed => {text: text}
                                                    }
                                  }
        expect(response.status).to eq(302)
        expect(assigns(:new_customers_not_allowed).text).to eq(text)
      end

      it 'should enable announcement during open hours' do
        post :announcement, params: {:announcement => {
                                                        :open => {enabled: true}
                                                      }
                                  }
        expect(response.status).to eq(200)
        expect(assigns(:announcement_open).enabled).to eq(true)
      end

      it 'should enable announcement during closed hours' do
        post :announcement, params: {:announcement => {
                                                        :closed => {enabled: true}
                                                      }
                                  }
        expect(response.status).to eq(200)
        expect(assigns(:announcement_closed).enabled).to eq(true)
      end

      it 'should not save announcement_open announcement_closed from wrong request' do
        open_text = "Hey!! This is announcement for open"
        closed_text = "Hey!! This is announcement for open"
        post :announcement, params: {:announcement => {
                                                        :open_text => {text: open_text},
                                                        :closed_text => {text: closed_text}
                                                      }
                                    }
        expect(response.status).to eq(200)
        expect(assigns(:announcement_open).text).to_not eq(open_text)
        expect(assigns(:announcement_closed).text).to_not eq(closed_text)
      end

    end
  end

  describe 'Service And Resources' do
    context 'GET service_and_resources', vcr: { cassette_name: 'timify_services'} do
      it 'should return service node' do
        ivr.update(preference: {"service_or_resource"=>"Services"})
        get :service_and_resources
        expect(response.status).to eq(200)
        expect(assigns(:node).name).to eq("select_service")
        expect(assigns(:service_node).name).to eq("select_service")
        expect(assigns(:resource_node).name).to eq("select_resource")
      end

      it 'should return resource node' do
        ivr.update(preference: {"service_or_resource"=>"Resources"})
        get :service_and_resources
        expect(response.status).to eq(200)
        expect(assigns(:node).name).to eq("select_resource")
        expect(assigns(:service_node).name).to eq("select_service")
        expect(assigns(:resource_node).name).to eq("select_resource")
      end
    end

    context 'POST service_and_resources', vcr: { cassette_name: 'timify_services'} do
      it 'should return service node' do
        ivr.update(preference: {"service_or_resource"=>"Services"})
        post :service_and_resources, params: {ivr: {preference: "Services"}, node: {enabled: true}}
        expect(response.status).to eq(200)
        expect(assigns(:node).name).to eq("select_service")
        expect(assigns(:service_node).name).to eq("select_service")
        expect(assigns(:resource_node).name).to eq("select_resource")
      end

      it 'should return resource node' do
        ivr.update(preference: {"service_or_resource"=>"Resources"})
        post :service_and_resources, params: {ivr: {preference: "Resources"}, node: {enabled: true}}
        expect(response.status).to eq(200)
        expect(assigns(:node).name).to eq("select_resource")
        expect(assigns(:service_node).name).to eq("select_service")
        expect(assigns(:resource_node).name).to eq("select_resource")
      end
    end

  end

  describe 'Configure Service And Resources' do
    context 'POST configure_resource_services', vcr: { cassette_name: 'timify_services'} do
      it 'should create resources for service' do
        ivr.update(preference: {"service_or_resource"=>"Services"})
        ivr.services.delete_all
        ivr.resources.delete_all
        data_params = {service: {service: "5d9f2ac56d95c0112ca1ccab", resource: ["5d9f2a7b6d95c0112ca1cc91"]}}
        post :configure_resource_services, params: data_params
        expect(ivr.services.count).to eq(1)
        expect(ivr.resources.count).to eq(1)
      end

      it 'should create services for resources' do
        ivr.update(preference: {"service_or_resource"=>"Resources"})
        ivr.services.delete_all
        ivr.resources.delete_all
        data_params = {resource: {resource: "5a2aa6765ce85c0f21a01ec0", service: ["5a2aa7bd5ce85c0f21a01ef7"]}}
        post :configure_resource_services, params: data_params
        expect(ivr.services.count).to eq(1)
        expect(ivr.resources.count).to eq(1)
      end
    end
  end

  describe 'Delete local Service And Resources' do
    context 'GET delete_resources', vcr: { cassette_name: 'timify_services'} do
      it 'should delete the service' do
        ivr.update(preference: {"service_or_resource"=>"Resources"})
        agenda_app.configure_resources(["5a2aa6765ce85c0f21a01ec0"])
        resources = ivr.resources.active
        resources_count = resources.count
        get :delete_resources, params: {id: resources.first.id}
        expect(ivr.resources.active.count).to eq(0)
      end

      it 'should delete the services' do
        ivr.update(preference: {"service_or_resource"=>"Services"})
        agenda_app.configure_services(["5a2aa7bd5ce85c0f21a01ef7"])
        services = ivr.services.active
        resources_count = services.count
        get :delete_resources, params: {id: services.first.id}
        expect(ivr.services.active.count).to eq(0)
      end
    end
  end

  describe 'should update preference' do
    context 'GET cancellation nodes', vcr: { cassette_name: 'timify_services'} do
      it 'should get nodes' do
        get :cancellation
        expect(assigns(:cmd_node).name).to eq('cmd_menu')
        expect(assigns(:modify_menu).name).to eq('modify_menu')
        expect(assigns(:say_modified).name).to eq('say_modified')
        expect(assigns(:cancel_menu).name).to eq('cancel_menu')
        expect(assigns(:say_cancelled).name).to eq('say_cancelled')
      end
    end

    context 'POST cancellation', vcr: { cassette_name: 'timify_services'} do
      it 'should update texts' do
        post :cancellation, params: { :preference =>  {
                                                        :allow_cancel_or_modify => "true"
                                                      },
                                      :cancel_time_offset => "1_day",
                                      :cmd_node =>    { 
                                                        text: "update cmd_node text"
                                                      },
                                      :say_modified =>  { 
                                                          text: "update say_modified text"
                                                        },
                                      :say_cancelled  =>  { 
                                                            text: "update say_cancelled text"
                                                          },
                                      :cancel_menu  =>    { 
                                                            text: "update cancel_menu text"
                                                          },
                                      :modify_menu  =>    { 
                                                            text: "update modify_menu text"
                                                          },
                                      :say_cancel_time_limit_reached => { text: "update say_cancel_time_limit_reached text"},
                                      :max_appointment_limit_reached => { text: "update max_appointment_limit_reached text"}
                                    }
        expect(assigns(:ivr).preference["allow_cancel_or_modify"]).to eq(true)
        expect(assigns(:cmd_node).text).to eq("update cmd_node text")
        expect(assigns(:say_modified).text).to eq("update say_modified text")
        expect(assigns(:say_cancelled).text).to eq("update say_cancelled text")
        expect(assigns(:cancel_menu).text).to eq("update cancel_menu text")
        expect(assigns(:modify_menu).text).to eq("update modify_menu text")
        expect(assigns(:say_cancel_time_limit_reached).text).to eq("update say_cancel_time_limit_reached text")
        expect(assigns(:max_appointment_limit_reached).text).to eq("update max_appointment_limit_reached text")
      end

    end

  end

  describe 'confirmation' do
    context 'GET confirm nodes', vcr: { cassette_name: 'confirm'} do
      it 'should get confirm nodes' do
        get :confirmation
        expect(assigns(:confirm).name).to eq('appointment_success')
        expect(assigns(:confirm2).name).to eq('appointment_success_caller_sms')
        expect(assigns(:confirm3).name).to eq('appointment_success_record')
        expect(assigns(:confirm_create).name).to eq('confirm_create')
        expect(assigns(:appointment_success_client_sms).name).to eq('appointment_success_client_sms')
      end
    end

    context 'POST confirmation' do
      it 'should save appointment_success nodes' do
        confirm_text = "Thank you %{customer_first_name}, your appointment for %{%{time}} is confirmed. We look forward to seeing you! Goodbye."
        confirm2_text = "Please record your name after the beep."
        confirm3_text = "Please record your name"
        confirm_create = "To confirm, Press 1. To go back, Press 0."
        appointment_success_client_sms_text = "This is text for appointment_success_client_sms node"
        post :confirmation, params: {:confirm =>  {
                                                    text: confirm_text
                                                  },
                                      :confirm2 => {
                                                      text: confirm2_text
                                                    },
                                      :confirm3 => {
                                                      text: confirm3_text
                                                    },
                                      :confirm_create => {
                                                      text: confirm_create
                                                    },
                                      :appointment_success_client_sms => {
                                                      text: appointment_success_client_sms_text
                                                    }

                                    }
        expect(response.status).to eq(200)
        expect(assigns(:confirm).name).to eq('appointment_success')
        expect(assigns(:confirm).text).to eq(confirm_text)
        expect(assigns(:confirm2).name).to eq('appointment_success_caller_sms')
        expect(assigns(:confirm2).text).to eq(confirm2_text)
        expect(assigns(:confirm3).name).to eq('appointment_success_record')
        expect(assigns(:confirm3).text).to eq(confirm3_text)
        expect(assigns(:confirm_create).name).to eq('confirm_create')
        expect(assigns(:confirm_create).text).to eq(confirm_create)
        expect(assigns(:appointment_success_client_sms).name).to eq('appointment_success_client_sms')
        expect(assigns(:appointment_success_client_sms).text).to eq(appointment_success_client_sms_text)
      end
    end
  end

end
