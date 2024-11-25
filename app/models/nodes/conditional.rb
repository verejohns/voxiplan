class Conditional < Node
  def execute
    schedule_background_job
    result = check_conditions
    save_data(result)

    puts "******** result #{result}"
    if result
      next_node.try(:run, @options)
    else
      invalid_next_node.try(:run, @options)
    end
  end

  def check_conditions
    # left_operand = interpolated_values(self.left_operand) || 0
    # right_operand = interpolated_values(self.right_operand) || 0
    puts "******* left_operand: #{self.left_operand}, right_operand: #{self.right_operand}"
    left_operand = interpolated_values(self.left_operand)
    right_operand = interpolated_values(self.right_operand)

    puts "******** check conditions #{left_operand} (#{left_operand.class}) #{self.condition} #{right_operand} (#{right_operand.class})"
    case self.condition
      when 'eq'
        left_operand == right_operand
      when 'lt'
        left_operand < right_operand
      when 'gt'
        left_operand > right_operand
      when 'lteq'
        left_operand <= right_operand
      when 'gteq'
        left_operand >= right_operand
      when 'or'
        !!left_operand or !!right_operand
      when 'and'
        !!left_operand and !!right_operand
      when 'in'
        [right_operand].flatten.include?(left_operand)
    end
  end

  def schedule_background_job
    # TODO: Move logic to appropriate place (separate node)
    # To avoid checking condition for every node
    return unless name == 'announcement_wrt_business_hours'
    return unless current_call && agenda_app
    return unless ivr.ai_bot_enabled?
    InitiateAiBotJob.perform_later(agenda_app.id, current_call.id, self.locale_from_message, data.slice(:session_id, :caller_id))
  end

  def self.available_conditions
    [
        'eq', # equal to
        'lt', # less then
        'gt', # greater then
        'lteq', # less then equal to
        'gteq'  # greater then equal to
    ]
  end

end

