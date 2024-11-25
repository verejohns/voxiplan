require 'rails_helper'

RSpec.describe Conditional, type: :model do
  before { travel_to(test_time) }
  after { travel_back }

  let(:start_time) {'09:00'}
  let(:end_time) {'17:00'}
  let(:start_time2) {'19:00'}
  let(:end_time2) {'21:00'}
  let(:start_time3) {'21:30'}
  let(:end_time3) {'23:00'}


  let(:business_hours) do
    BusinessHours.new(
        name: 'test',
        business_hours:
            {mon: [{from: start_time, to: end_time}, {from: start_time2, to: end_time2}, {from: start_time3, to: end_time3}],
             tue: [{from: start_time, to: end_time}, {from: start_time2, to: end_time2}, {from: start_time3, to: end_time3}],
             wed: [{from: start_time, to: end_time}, {from: start_time2, to: end_time2}, {from: start_time3, to: end_time3}],
             thu: [{from: start_time, to: end_time}, {from: start_time2, to: end_time2}, {from: start_time3, to: end_time3}],
             fri: [{from: start_time, to: end_time}, {from: start_time2, to: end_time2}, {from: start_time3, to: end_time3}]
            })
  end

  describe 'open hours' do
    let(:test_time) {Time.zone.local(2018, 12, 18, 10, 00)}

    it 'should be within open hours' do
      expect(BusinessHours.within_biz_hours(business_hours.business_hours)).to be_truthy
    end
  end

  describe 'close hours' do
    let(:test_time) {Time.zone.local(2018, 12, 18, 07, 00)}

    it 'should be within open hours' do
      expect(BusinessHours.within_biz_hours(business_hours.business_hours)).to be_falsy
    end
  end

  describe 'open hours before 2nd interval' do
    let(:test_time) {Time.zone.local(2018, 12, 18, 22, 00)}

    it 'should be within open hours before 2nd interval' do
      expect(BusinessHours.within_biz_hours(business_hours.business_hours)).to be_truthy
    end
  end

  describe 'close hours after 2nd interval' do
    let(:test_time) {Time.zone.local(2018, 12, 18, 21, 10)}

    it 'should be within open hours after 2nd interval' do
      expect(BusinessHours.within_biz_hours(business_hours.business_hours)).to be_falsy
    end
  end


end
