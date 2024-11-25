require 'rails_helper'

RSpec.describe Arithmetic, type: :model do

  let(:node) { Arithmetic.create(name: 'a1', condition: condition, left_operand: "%{op1}", right_operand: "%{op2}")}
  let(:data) {{op1: op1, op2: op2}}
  let(:result) {node.calculate}

  before do
    allow(node).to receive(:data) { data }
    allow(node).to receive(:ivr) { double(nodes: double(find_by: nil), preference: {voice_engin: 'twilio'}) }
  end

  describe 'run' do
    let(:op1) {2}
    let(:op2) {1}

    context '+' do
      let(:condition) {'+'}

      it 'adds two numbers and stores result' do
        node.run(data)
        expect(data[:a1]).to eq 3
      end

      context 'left operand is not initialized' do
        let(:data) {{op2: op2}}

        it 'starts from 0 ' do
          node.run(data)
          expect(data[:a1]).to eq 1
        end
      end

    end

    context '-' do
      let(:condition) {'-'}

      it 'adds two numbers and stores result' do
        node.run(data)
        expect(data[:a1]).to eq 1
      end
    end
  end

end
