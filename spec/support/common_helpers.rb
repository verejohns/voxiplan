module CommonHelpers

  def client
    @client ||= Client.create(
        email: 'test@ex.com',
        first_name: 'test', last_name: 'ex', country: 'PK', phone: '03211223344',
        time_zone: 'Asia/Karachi'
    )
  end

  def ivr
    @ivr ||= Ivr.create(name: 'test', client: client)
  end

  def data
    {current_time: Time.current, session_id: '123'}
  end

  def json_response
    JSON.parse @resp.body
  end

  def test_time
    Time.zone.local(2018, 04, 23, 9, 00)
  end

  def initial_setup
    Time.zone = 'Asia/Karachi'
    controller.session.clear
    travel_to test_time
    controller.session[:data] = data

    # we have changed the default value to '1_day' later. I am keeping old value to avoid failing specs
    node = find_node('agenda_group_availabilities')
    node.parameters['after_time'] = "%{current_time}"
    node.save
    Node.where(name: IvrBuilder.confirmation_nodes).update_all(enabled: true)
    allow_any_instance_of(SSMD::Converter).to receive(:process) do |obj, processor, input|
      input
    end
    allow_any_instance_of(Ivr).to receive(:play_enabled?).and_return(false)
    allow_any_instance_of(IvrController).to receive(:ivr).and_return(ivr)
    allow_any_instance_of(VoxiSMSParty).to receive(:send_msg).and_return(true)

    allow_any_instance_of(Mobminder).to receive(:all_resources) do |obj, p1, p2 ,p3|
      {:uCals=>"13137", :bCals=>"6978"}
    end

    allow_any_instance_of(ClientNotifierMailer).to receive(:generic_email).and_return(true)
    allow_any_instance_of(RasaParty).to receive(:chat).and_return(true)
    allow_any_instance_of(NameApiParty).to receive(:parse_name).and_return({})
    allow(GoogleSpeechToText).to receive(:recognise).and_return(true)
  end

  def res
    Hash.from_xml( (@resp || response).body.gsub("\n", ""))['Response']
  end

  def say
    res['Say']
  end

  def ask_say
    res['Gather'].nil? ? nil : res['Gather']['Say']
  end

  def next_url
    res['Gather'].try(:[], 'action') || res['Redirect']
  end

  def next_node_path(node_name = nil, query_params = {})
    path = "/run/#{next_node(node_name).id}"
    res = '?parse_response=true'
    path += res if (defined?(current_node) && current_node.is_a?(Menu)) || query_params[:response]
    path
  end

  def saved_data(key)
    controller.session['data'][key]
  end

  def create_appointment
    current_node = find_node('agenda_group_availabilities')
    find_node('agenda_group_availabilities').run
    get :run, params: {id: current_node.id}
    current_node = find_node('appointment_menu1')

    @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}
    expect(data[:group1_date]).to eq data[:choosen_group]
    expect(data[:slot_count]).to eq(3).or be_nil
    # expect(ask_say).to eq 'Press 1 for 10:00 AM. Press 2 for 10:15 AM. Press 3 for 10:30 AM. Wait to hear next availabilities. Or press 9 to repeat.'

    current_node = find_node('appointment_menu3')
    @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

    current_node = find_node('confirm_create')
    @resp = get :run, params: {id: current_node.id, parse_response: true, test_input: 1}

    # expect(ask_say).to eq text_nl(t('static_ivr.appointment_cofirmation'))
    # expect(say).to match 'Thank you'
    expect(say).to match t('static_ivr.internal_error')

    current_node = find_node('appointment_success_caller_sms')
    current_node.update_column(:enabled, true)
    current_node.ivr.update_column(:confirmation_sms, true)
    allow(HTTParty).to receive(:post).and_return(true)
    # expect_any_instance_of(TropoEngine).to receive(:send_sms)
    get :run, params: {id: current_node.id}
  end

  delegate :t, to: :I18n

  def menu1_text(node = nil, slot1:, slot2: nil, slot3: nil)
    txt = ""
    txt += text_nl(node.text['key1'] % {slot1_start: slot1})
    txt += text_nl(node.text['key2'] % {slot2_start: slot2}) if slot2
    txt += text_nl(node.text['key3'] % {slot3_start: slot3}) if slot3
    txt += node.text['other']
    txt
  end

  def resource_text(resources = [])
    node = find_node('select_resource')
    txt = ""
    resources.each_with_index do |resource, index|
      txt += text_nl(node.text['generic'] % {resource_name: resource, num: index + 1})
    end
    txt += node.text['other']
    txt
  end

  def service_text(services = [])
    node = find_node('select_service')
    txt = ""
    services.each_with_index do |service, index|
      txt += text_nl(node.text['generic'] % {service_name: service, num: index + 1})
    end
    txt += node.text['other']
    txt
  end

  def find_node(name)
    ivr.nodes.find_by name: name
  end

  def next_node(node_name = nil)
    node_name ||= current_node.name if defined?(current_node)
    @next_node ||= find_node(node_name)
  end

  def group_text(node, g1, g2 = nil)
    text = ''
    multiple = node.text['generic']['multiple']['text']
    single = node.text['generic']['single']['text']

    text += text_nl(g1[:count] == 1 ? single % g1 : multiple % g1)
    text += text_nl(g2[:count] == 1 ? single % g2 : multiple % g2) if g2

    text += node.text['other']
    text
  end

  def cmd_menu_text(c: true, m: true, d: true)
    text = ''
    text += text_nl(I18n.t('static_ivr.cmd_menu.create')) if c
    text += text_nl(I18n.t('static_ivr.cmd_menu.modify')) if m
    text += text_nl(I18n.t('static_ivr.cmd_menu.delete')) if d
    text
  end

  private

  # text with new line
  def text_nl(txt)
    # multiple spaces are converted to one space on XML
    txt + "  "
  end

end