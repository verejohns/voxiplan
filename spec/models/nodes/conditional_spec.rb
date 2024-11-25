require 'rails_helper'

RSpec.describe Conditional, type: :model do

  let(:node) { Conditional.create(name: 'c1', left_operand: "%{op1}", right_operand: "%{op2}")}
  let(:data) {{op1: op1, op2: op2}}
  let(:result) {node.check_conditions}

  def create_specs_with(conditions)

  end

  describe '#check_conditions' do

    before do
      allow(node).to receive(:data) { data }
    end

    describe 'integers' do
      let(:op1) {1}
      let(:op2) {2}
      conditions = {'eq': false, 'lt': true, 'gt': false ,'lteq': true, 'gteq': false }

      conditions.each do |condition, expected|
        it "#{condition}" do
          node.condition = condition
          expect(result).to be expected
        end
      end
    end

    describe 'Dates' do
      let(:op1) {Time.current}
      let(:op2) {Time.current + 2.hours}
      conditions = {'eq': false, 'lt': true, 'gt': false ,'lteq': true, 'gteq': false }

      conditions.each do |condition, expected|
        it "#{condition}" do
          node.condition = condition
          expect(result).to be expected
        end
      end
    end

    describe 'Strings' do
      let(:op1) {'abc'}
      let(:op2) {'abc'}
      conditions = {'eq': true, 'lt': false, 'gt': false ,'lteq': true, 'gteq': true }

      conditions.each do |condition, expected|
        it "#{condition}" do
          node.condition = condition
          expect(result).to be expected
        end
      end
    end

    describe 'in' do
      let(:op1) {1}
      let(:op2) {[1,2,3]}

      it 'should be true' do
        node.condition = 'in'
        expect(result).to be_truthy
      end
    end

    describe 'and' do
      let(:op1) {true}
      let(:op2) {true}

      it 'should be true' do
        node.condition = 'and'
        expect(result).to be_truthy
      end
    end

    describe 'or' do
      let(:op1) {true}
      let(:op2) {false}

      it 'should be true' do
        node.condition = 'or'
        expect(result).to be_truthy
      end
    end

  end

end
