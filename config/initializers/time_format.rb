Time::DATE_FORMATS.merge!(
    custom: lambda { |time| time.strftime("#{time.day.ordinalize} of %B at %I:%M %p") } # [DAY OF THE WEEK, DATE at HOUR] = "Tuesday, 9th of April at 11.15 AM".
)