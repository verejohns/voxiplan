require 'rails_helper'

RSpec.describe Menu, type: :model do
  def cmd_menu_text(c: true, m: true, d: true)
    text = ''
    text += text_nl(I18n.t('static_ivr.cmd_menu.modify')) if m
    text += text_nl(I18n.t('static_ivr.cmd_menu.delete')) if d
    text += text_nl(I18n.t('static_ivr.cmd_menu.create')) if c
    text
  end

  def text_nl(txt)
    # multiple spaces are converted to one space on XML
    txt + " \n "
  end

  let(:text) {
    {
      modify: { text: I18n.t('static_ivr.cmd_menu.modify')},
      delete: { text: I18n.t('static_ivr.cmd_menu.delete')},
      create: { text: I18n.t('static_ivr.cmd_menu.create'), condition: '%{can_create}'}
    }
  }
  let(:node) { Menu.create(text: text, name: 'cmd', choices: {}, parameters: {text_concat_method: 'conditions'})}
  let(:data) {{can_create: false}}
  let(:ivr) { double(nodes: double(find_by: nil), voice: '', voice_locale: 'en-US', preference: {'voice_engin' => 'twilio'}) }

  before do
    allow(node).to receive(:data) { data }
    allow(node).to receive(:ivr) { ivr }
  end

  describe 'conditional text' do
    it 'should not ask to create an appointment' do
      allow(ivr).to receive(:play_enabled?).and_return(false)
      node.run
      expect(node.text).to eq cmd_menu_text(c: false)
    end

    context 'condition true' do
      let(:data) {{can_create: true}}

      it 'should ask' do
        allow(ivr).to receive(:play_enabled?).and_return(false)
        node.run
        # expect(node.text).to eq 'To modify an appointment press 1. To delete an appointment press 2. To create an appointment press 3.'
        expect(node.text).to eq cmd_menu_text
      end
    end
  end

end
