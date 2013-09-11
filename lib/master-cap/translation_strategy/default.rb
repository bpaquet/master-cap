
class DefaultTranslationStrategy

  def node_name env, name, node, topology
    return name.to_s if topology[:no_node_suffix]
    "#{name}-#{env}"
  end

  def node_hostname env, name, node, topology
    return node[:hostname] if node[:hostname]
    raise "No hostname in #{node}"
  end

  def vm_name env, name, node, topology
    node_name env, name, node, topology
  end

end