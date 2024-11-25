require 'rails_helper'

RSpec.describe InterpolationUtils, type: :model do
  before do
    class TestClass
      include InterpolationUtils
    end
  end

  describe '#formatted_time' do
    let(:time) { Time.zone.local(2020, 12, 23, 9, 00) }
    let(:format) { :custom }

    subject { TestClass.new.formatted_time(time, locale: locale, format: format) }

    context 'greek' do
      let(:locale) { :el }

      it 'returns genitive form of month for greek' do
        expect(subject).to match('Δεκεμβρίου')
      end

      context 'date' do
        let(:time) { Date.new(2020, 12, 23)}
        let(:format) { :weekday_and_num }

        it 'returns genitive form of month for greek' do
          expect(subject).to match('Δεκεμβρίου')
        end
      end
    end

    context 'en' do
      let(:locale) { :en }

      it 'works' do
        expect(subject).to include 'December'
      end
    end
  end
end
