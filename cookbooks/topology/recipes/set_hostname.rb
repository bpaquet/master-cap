
service "hostname" do
  supports :restart => true
  action auto_compute_action
end


p node[:topology_node_name]
p node.topology
file "/etc/hostname" do
  content node.topology[node[:topology_node_name]][:topology_hostname]
  mode '0644'
  notifies :restart, "service[hostname]"
end