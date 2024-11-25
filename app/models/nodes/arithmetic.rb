class Arithmetic < Node
  def execute
    result = calculate
    save_data(result)

    next_node.try(:run, @options)
  end

  def calculate
    left_operand = interpolated_values(self.left_operand).to_i
    right_operand = interpolated_values(self.right_operand).to_i

    puts "******** #{left_operand} (#{left_operand.class}) #{self.condition} #{right_operand} (#{right_operand.class})"
    case self.condition
      when '+'
        left_operand + right_operand
      when '-'
        left_operand - right_operand
    end
  end

end

