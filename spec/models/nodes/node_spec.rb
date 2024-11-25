require 'rails_helper'

RSpec.describe Node, type: :model do

  let(:node) { Node.create(name: 'n1')}
  let(:data) {{}}

  before do
    allow(node).to receive(:data) { data }
  end

  describe '#save_data' do
    before{ node.save_data('3') }
    it 'saves date' do
      expect(data[:n1]).to eq '3'
      expect(node.data[:n1]).to eq '3'
    end
  end

  describe 'interpolated_expression_value' do

    context 'when both operands are variables' do
      before do
        data[:op1] = 3
        data[:op2] = 2
      end

      operators = %w[+ - < > <= >=]
      results = [5, 1, false, true, false, true]

      operators.each_with_index do |operator, index|
        it "%{op1 #{operator} op2}" do
          exp = "%{op1 #{operator} op2}"
          result = node.interpolated_expression_value(exp)
          expect(result).to eq results[index]
        end
      end
    end

    context 'mixed operands' do

      before do
        data[:op1] = 3
      end

      operators = %w[+ - < > <= >=]
      results = [5, 1, false, true, false, true]

      operators.each_with_index do |operator, index|
        it "%{op1 #{operator} 2}" do
          exp = "%{op1 #{operator} #{2}}"
          result = node.interpolated_expression_value(exp)
          expect(result).to eq results[index]
        end
      end
    end

    it 'should return same outptut as input if str is not a valid expression' do
      result = node.interpolated_expression_value("%{count}")
      expect(result).to eq "%{count}"
    end
  end

end
