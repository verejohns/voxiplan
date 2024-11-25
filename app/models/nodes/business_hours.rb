class BusinessHours < Node

  DEFAULT_AVAILABILITY = {
    'mon': [{'from': '09:00', to: '17:00'}],
    'tue': [{'from': '09:00', to: '17:00'}],
    'wed': [{'from': '09:00', to: '17:00'}],
    'thu': [{'from': '09:00', to: '17:00'}],
    'fri': [{'from': '09:00', to: '17:00'}]
  }

  AVAILABLE_24H = {
    'mon': [{'from': '00:00', to: '24:00'}],
    'tue': [{'from': '00:00', to: '24:00'}],
    'wed': [{'from': '00:00', to: '24:00'}],
    'thu': [{'from': '00:00', to: '24:00'}],
    'fri': [{'from': '00:00', to: '24:00'}],
    'sat': [{'from': '00:00', to: '24:00'}],
    'sun': [{'from': '00:00', to: '24:00'}]
  }

  DEFAULT_DURATION = 30

  def execute
    within_biz_hours = self.class.within_biz_hours(self.business_hours, self.overrides)
    save_data(within_biz_hours)

    if within_biz_hours
      next_node.try(:run, @options)
    else
      invalid_next_node.try(:run, @options)
    end
  end

  def self.within_biz_hours(business_hours, overrides = nil)
    shifts = Hash.new
    holidays = []
    overrides&.each do |key, override|
      if override[0]['from'].nil? || override[0]['to'].nil?   # it means unavailable
        holidays.push(Date.parse(key))
      else
        shifts[Date.parse(key)] = {override[0]['from'] => override[0]['to']}
      end
    end

    biz_schedule = Biz::Schedule.new do |config|
      config.hours = business_hours.deep_symbolize_keys.transform_values{|v| v.map{|h| [h[:from], h[:to]]}.to_h}
      config.shifts = shifts
      config.holidays = holidays unless holidays.count.zero?
      config.time_zone = ActiveSupport::TimeZone::MAPPING[Time.zone.name] || Time.zone.name # this should already be set according to zone of client
    end
    biz_schedule.in_hours?(Time.current)
  end
end