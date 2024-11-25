module PhoneNumberUtils
  # sanitize phone numbers format before comparing
  def sanitize(phone, country = nil)
    parse_phone(phone, country).sanitized
  end

  def valid_international_or_local(number, country = nil)
    phone = Phonelib.parse(number)
    if phone.valid?
      voxi_phone(phone)
    elsif Phonelib.valid_for_country? number, country
      voxi_phone(number, country)
    end
  end

  # standard format that we'll use in voxiplan
  def voxi_phone(phone, country = nil)
    return unless phone.present?
    phone = parse_phone(phone, country) if phone.kind_of? String

    # remove initial '+' from e164
    phone.try(:e164).try( :[], 1..-1 )
  end

  def parse_phone(phone, country = nil)
    Phonelib.parse(phone, country)
  end
end