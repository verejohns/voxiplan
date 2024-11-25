class Menu < TelephonyNode

  def execute
    if @options.delete(:parse_response)
      handle_response
    else
      set_menu_text
      telephony.menu
    end
  end

  def set_menu_text
    if self.text.is_a?(Hash)
      if self.parameters.try(:[], 'text_concat_method') == 'conditions'
        self.text = text_according_to_conditions(self.text)
      elsif things_count
        save_data(things_count, key: :things_count)
        if self.parameters.try(:[], 'text_concat_method') == 'generic_with_conditions'
          self.text = generic_text_with_conditions
        else
          self.text = text_according_to_slot_count
        end
      end
    end

    self.text = self.text % dup_data
  end

  # things_count variable is useful to keep track of last number of slots, resource ete
  # useful for repeating a menu
  def things_count
    @things_count ||= @options[:slot_count] || data[:things_count] || data[parameters.try(:[],'count_variable').try(:to_sym)]
  end

  # ex {create: { text: 'To create an appointment press 3.', condition: '%{can_create}'}}
  def text_according_to_conditions(hash)
    text = ""
    hash.each do |_,v|
      condition = v['condition']
      show = condition.nil? || interpolated_expression_value(condition) == true || interpolated_value(condition) == true
      text += text_nl(v['text']) if show
    end
    text
  end

  def generic_text_with_conditions
    text = ""
    things_count.times do |index|
      num = index + 1

      self.text['generic'].each do |_,v|
        exp = "%{#{v['condition'] % {num: num}}}"
        show = exp.nil? || interpolated_expression_value(exp) == true || interpolated_value(exp) == true
        if show
          variables = v['variables'].transform_values{ |v| val = v % {num: num} ; puts val.inspect ; val == num.to_s ? val : "%{#{val}}" }
          text += text_nl(v['text'] % variables.symbolize_keys)
        end
      end
      # choices["key_#{num}"] = parameters['selected_next'] if parameters['selected_next']
    end

    text + self.text['other']
  end

  def text_according_to_slot_count
    text = ""
    things_count.times do |index|
      num = index + 1
      if self.text['generic']
        d = {num: num, parameters['variable_name'].to_sym =>  "%{#{parameters['variable_name']}#{num}}"}
        text += text_nl(self.text['generic'] % d)
      else
        text += text_nl(self.text["key#{num}"])
      end

      choices["key_#{num}"] = parameters['selected_next'] if parameters['selected_next']
    end

    text + self.text['other']
  end

  def handle_response

    if timeout? && self.timeout_next
      data[:timeout_tries_count] ||= 1
      # if self.tries == 1 || (data[:timeout_tries_count] > (self.tries))
      if data[:timeout_tries_count] >= (self.tries || 3)
        data[:timeout_tries_count] = nil
        return self.timeout_next_node.run(@options)
      else
        data[:timeout_tries_count] += 1
        return self.run(@options)
      end
    end

    num = telephony.get_response[:value]
    save_data(num)
    # self.choices["key_#{num}"] = parameters['selected_next'] if parameters['selected_next']
    # for now we ask number again if invalid number is entered, we will add count later.
    # name = self.choices["key_#{num}"] || parameters.try(:[], 'selected_next') || self.invalid_next
    name = self.choices["key_#{num}"] || parameters.try(:[], 'selected_next') || self.name
    get_node(interpolated_value(name)).run(@options)
  end


  # text with new line
  def text_nl(txt)
    (txt || "") + " \n "
  end

end
