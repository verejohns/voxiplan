require 'rails_helper'

RSpec.describe SendEmail, type: :model do

  let(:recording) {Recording.create(url: '')}
  let(:node) do

    SendEmail.new(
        # to: 'work.teknuk@gmail.com',
        to: 'mian.mbilal.iqbal@gmail.com',
        text: {
            title: I18n.t("mails.client_appointment_confirmed.title"),
            greetings: I18n.t("mails.client_appointment_confirmed.greetings"),
            summary: I18n.t("mails.client_appointment_confirmed.summary"),
            booking_details: I18n.t("mails.client_appointment_confirmed.booking_details"),
            caller: I18n.t("mails.client_appointment_confirmed.caller"),
            date: I18n.t("mails.client_appointment_confirmed.date"),
            play_recording_btn_text: I18n.t("mails.client_appointment_confirmed.play_recording_btn_text"),
            play_recording_btn_url: I18n.t("mails.client_appointment_confirmed.play_recording_btn_url"),
            conclusion: I18n.t("mails.client_appointment_confirmed.conclusion"),
            copyright: I18n.t("mails.copyright"),
            reply_to_or_contact_us: I18n.t("mails.reply_to_or_contact_us"),
        },
        email_subject: "Test subject",
        parameters: {
            template_id: 'd-78cbb441410e49b4b5dd9bdedc3b639f'
        }
    )
  end

  let(:data) do
    {
        client_first_name: "Usman",
        caller_id: "+923001234567",
        email_full_name: 'Usman',
        email_contact_type: 'Returning',
        choosen_slot_start: "Tuesday, 4th of December 2018",
        choosen_resource: "Axel",
        choosen_service: "Test service",
        appointment_success_record: recording.voxi_url,
    }
  end

  before do
    allow(node).to receive(:data) { data }
    allow(node).to receive(:ivr) { double(nodes: double(find_by: nil), voice: '', voice_locale: 'en', preference: {'voice_engin' => 'twilio'}) }
  end

  it 'should send email', vcr: true do
    allow(GoogleSpeechToText).to receive(:recognise).and_return 'Usman'
    allow(node).to receive(:client_email?).and_return(false)

    puts "*********** data: #{data}"
    template_data = node.text.transform_values do |p|
      begin
        p % data
      rescue StandardError => e
        puts "********** could not find #{p}, ##{e.message} "
        ''
      end
    end
    options = {to: node.to, template_id: node.parameters['template_id'], subject: 'Test subject',  template_data: template_data.merge(subject: node.email_subject)}
    payload = SendgridMail.payload(options)
    data = payload['personalizations'][0]['dynamic_template_data']
    expect(data['greetings']).to include('Usman')
    node.run
  end
end

