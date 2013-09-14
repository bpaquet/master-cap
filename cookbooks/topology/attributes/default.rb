
topology_file = "/opt/master-chef/etc/topology.json"

if File.exist? topology_file

  Chef::Log.info("Loading topology from #{topology_file}")

  topology = JSON.parse(File.read(topology_file), :symbolize_names => true)
  node.set[:topology] = topology[:topology]
  node.set[:apps] = topology[:apps] if topology[:apps]
end

default[:registry] = {}
default[:urls] = {}