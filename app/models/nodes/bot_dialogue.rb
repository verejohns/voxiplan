class BotDialogue < Node
  def execute
    if Rails.cache.read("voxisession-#{data[:current_ivr_id]}-#{data[:caller_id]}")
      @options[:session_data][:session_id] = "voxi-#{Rails.cache.read("voxisession-#{data[:current_ivr_id]}-#{data[:caller_id]}")}"
    else
      voxi_session = VoxiSession.where(ivr_id: data[:current_ivr_id], client_id: data[:client_id], caller_id: data[:caller_id]).first
      if voxi_session
        @options[:session_data][:session_id] = "voxi-#{voxi_session.session_id}"
        Rails.cache.write("voxisession-#{data[:current_ivr_id]}-#{data[:caller_id]}", voxi_session.session_id)
      else
        session_id = data[:session_id].split('-').last
        Rails.cache.write("voxisession-#{data[:current_ivr_id]}-#{data[:caller_id]}", session_id)
        VoxiSession.create(ivr_id: data[:current_ivr_id], client_id: data[:client_id], caller_id: data[:caller_id], session_id: data[:session_id].split('-').last, platform: 'call')
      end
    end

    # Use only if different Rasa server for each language
    # bot_says = RasaParty.new(data[:session_id], self.locale_from_message).chat(message: data[:user_says].to_s.gsub("'", '"'))
    bot_says = RasaParty.new(data[:session_id], self.ivr.assistant_name, self.ivr.message_locale[0..1], self.ivr.preference['widget_tz'], "#{self.ivr.message_locale}-#{self.ivr.client.country_code}", "call").chat(message: data[:user_says].to_s.gsub("'", '"'))

    # s = ActiveRecord::SessionStore::Session.find_by(session_id: data[:session_id].split('-').last)
    # @options[:session_data].merge! s.data.dig('data') if s && s.data.dig('data')
    data[:bot_says] = bot_says
    run_next_node(bot_says)
  end

  def run_next_node(bot_says)
    action_node = find_next_action_node(bot_says)

    if action_node
      ai_bot_finish = ivr.find_node('ai_bot_finish')
      ai_bot_finish&.update(next: action_node)
      ai_bot_finish.try(:run, @options)
    else
      next_node.try(:run, @options)
    end
  end

  def find_next_action_node(bot_says)
    mapping = {
      '/transfer_or_voicemail' => 'transfer_or_voicemail_wrt_business_hours',
      '/goodbye' => 'hang',
    }

    mapping.each do |k,v|
      if bot_says.to_s.include?(k)
        data[:bot_says] = bot_says.gsub(k, '').strip
        return v
      end
    end

    nil
  end
end
