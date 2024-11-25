module DateTimeUtil
  def self.parse_if_datetime(v)
    date_regx = '[0-9]{4}-[0-9]{2}-[0-9]{2}'
    time_regx = "#{date_regx}T[0-9]{2}:[0-9]{2}"
    if v.match?(/#{time_regx}/)
      Time.parse v
    elsif v.match?(/#{date_regx}/)
      Date.parse v
    else
      v
    end
  end
end
