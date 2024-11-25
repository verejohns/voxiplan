class GatherPhoneNumber < GatherNumber

  def handle_response
    phone = Phonelib.parse(gathered_number)
    if phone.valid?
      puts "****** phone #{gathered_number} is valid for international format for #{phone.country}"
      @num = voxi_phone(phone)
      set_new_number_for_current_call
      super
    elsif Phonelib.valid_for_country? gathered_number, client_country
      puts "****** phone #{gathered_number} is valid for #{client_country} "
      @num = voxi_phone(gathered_number, client_country)
      set_new_number_for_current_call
      super
    else
      puts "****** phone #{gathered_number} is NOT valid for #{client_country} "
      invalid_next_node.run(@options)
    end
  end

  private

  def set_new_number_for_current_call
    current_call.update_column(:entered_number, @num)
  end
end
