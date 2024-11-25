class AiBot < AppointmentBot

  def build
    caller_id_and_announcement(next_node: 'ai_bot_start_conversation')
    create_ai_nodes
    START
  end

  def create_ai_nodes
    if @ivr.assistant_name == "Laura"
      right_operand = "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{@ivr.message_locale[0..1]}'}"
    else
      right_operand = "/greet{'client_identifier': '#{@ivr.uid}', 'language': '#{@ivr.message_locale[0..1]}', 'assistant_name': '#{@ivr.assistant_name}'}"
    end

    create(Variable, 'ai_bot_start_conversation',
           left_operand: 'user_says', right_operand: right_operand,
           next: 'ai_bot_dialogue')

    create(BotDialogue, 'ai_bot_dialogue', next: 'ai_bot_gather')
    create(BotGather, 'ai_bot_gather', next: 'ai_bot_dialogue', tries: 2)
  end

end
