
service "hostname" do
  supports :restart => true
  action :nothing
end

ohai "reload_hostname" do
  action :nothing
  plugin "hostname"
end

file "/etc/hostname" do
  content node.topology[node[:topology_node_name]][:topology_hostname]
  mode '0644'
  notifies :restart, "service[hostname]", :immediately
  notifies :run, "ohai[reload_hostname]"
end