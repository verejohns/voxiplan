module InterpolationUtils
  def interpolated_keys(str)
    return unless str.class == String
    r = str.scan(/%{(\w+)}/).flatten.map(&:to_sym)
    r.size > 1 ? r : r.first
  end

  def interpolated_values(obj)
    if obj.is_a? Array
      obj.map{|o| interpolated_value(o)}
    else
      interpolated_value(obj)
    end
  end

  def interpolated_value(str)
    keys = interpolated_keys(str)
    puts "interpolated_keys #{keys}"
    return str if keys.nil?
    r = data.values_at(*keys)
    ret  = r.size > 1 ? r : r.first
    return 888873 if ret.nil? && keys == :ivr_preference_max_allowed_appointments
    r.present? ? ret : str
  end

  def interpolated_expression_value(str)
    expression = str.scan(/%{\s*(\w+)\s*(\+|\-|\*|\>|\<|\<\=|\>\=|\=\=)*\s*(\w+)*\s*}/)[0]
    return str unless expression && expression.all?
    op1, exp , op2 = expression
    op1 = data[op1.to_sym] || str_to_boolean(op1) || op1.to_i
    op2 = data[op2.to_sym] || str_to_boolean(op2) || op2.to_i
    op1.send(exp, op2)
  end

  def str_to_boolean(str)
    boolean = str.match(/^(true|false)$/i)
    return nil unless boolean.present?
    boolean[0].downcase == 'true'
  end

  def formatted_time(time, locale: nil, format: nil)
    locale ||= 'en'
    format ||= interpolated_value(self.parameters['time_format']).try(:to_sym) rescue :custom
    format ||= :custom

    if time.is_a?(Time) || time.is_a?(DateTime)
      format = :long unless I18n.exists?("time.formats.#{format}", locale)
    elsif time.is_a?(Date)
      format = :long unless I18n.exists?("date.formats.#{format}", locale)
    end

    I18n.l(time, format: format, locale: locale, day: time.day.ordinalize, greek_month: GreekMonth.genitive(time.month))
  end
end
