module NodeUtils
  def save_node(object, params)
    text = nested_merge(object.text, params[:text])
    if object.update(text: text, enabled: params[:enabled].present?)
      flash[:success] = "Your changes were saved!"
    else
      flash[:danger] = object.errors.full_messages
    end
  end

  def nested_merge(first, second)
    return second unless first.is_a?(Hash)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    first.merge(second, &merger)
  end

  def create_variables(ivr, nodes)
    result = ivr.nodes.where(name: nodes)
    result.each do |node|
      self.instance_variable_set("@#{node.name}", node)
    end
  end

  def save_node_text(object, params)
    text = nested_merge(object.text, params[:text])
    if object.update(text: text)
      flash[:success] = "Your changes were saved!"
    else
      flash[:danger] = object.errors.full_messages
    end
  end

  def get_node(ivr, node_name)
    ivr.nodes.find_by!(name: node_name)
  end

  def get_nodes(ivr, node_names)
    node_names.map{|node_name| get_node(ivr, node_name)}
  end
end