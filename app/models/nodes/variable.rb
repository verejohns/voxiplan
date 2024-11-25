class Variable < Node
  def execute
    # if self.left_operand == "user_says"
    #   result = Rails.cache.read("voxisession-user_says")
    #
    #   unless result
    #     result = calculate
    #     Rails.cache.write("voxisession-user_says", result)
    #   end
    #
    #   save_data(result, key: "user_says")
    # else
    #   result = calculate
    #   save_data(result, key: self.left_operand)
    # end

    result = calculate
    save_data(result, key: self.left_operand)

    next_node.try(:run, @options)
  end

  def calculate
    interpolated_values(self.right_operand)
  end

end

