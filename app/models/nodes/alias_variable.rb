class AliasVariable < Node
  def execute
    parameters.each do |p|
      data[p['alias'].to_sym] = data[p['original'].to_sym] if data[p['original'].to_sym]
    end

    next_node.run(@options)
  end

  # def parameters
  #   [{original: 'slot1_start', alias: 'choosen_slot_start'},
  #   {original: 'slot1_finish', alias: 'choosen_slot_finish'},
  #   {original: 'slot1_id', alias: 'choosen_slot_id'}]
  # end
end
