class GatherNumber < TelephonyNode
  def execute
    if @options.delete(:parse_response)
      handle_response
    else
      telephony.gather_number
    end
  end

  def handle_response
    save_data(gathered_number)
    next_node.run(@options)
  end

  def gathered_number
    @num ||= telephony.get_response[:value]
  end

end
