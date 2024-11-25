require 'rails_helper'

RSpec.describe Variable, type: :model do

  let(:node) { Variable.create(name: 'v1', right_operand: "%{op2}")}
  let(:op2) {1}
  let(:data) {{op2: op2}}

  before do
    allow(node).to receive(:data) { data }
    allow(node).to receive(:ivr) { double(nodes: double(find_by: nil), preference: {voice_engin: 'twilio'}) }
  end

  describe 'run' do

    it 'initialize variable from interpolated string' do
      node.run(data)
      expect(data[:v1]).to eq 1
    end

    it 'creates variable from give value' do
      node.right_operand = 2
      node.run(data)
      expect(data[:v1]).to eq 2
    end

    it 'sets value to nil' do
      node.right_operand = "%{nil}"
      node.run(data)
      expect(data[:v1]).to eq nil
    end
  end

end
