
require File.join(File.dirname(__FILE__), 'topology.rb')

Capistrano::Configuration.instance.load do

  topology_directory = fetch(:topology_directory, 'topology')

  task :load_topology do
    Dir["#{topology_directory}/*.yml"].each do |f|
      env = File.basename(f).split('.')[0]
      TOPOLOGY[env] = YAML.load(File.read(f))
      nodes = []
      roles_map = {}
      default_role_nodes = []
      TOPOLOGY[env][:topology].each do |k, v|
        v[:topology_name] = translation_strategy.node_name(env, k, v, TOPOLOGY[env])
        v[:topology_hostname] = begin translation_strategy.node_hostname(env, k, v, TOPOLOGY[env]) rescue nil end
        next unless v[:topology_hostname]
        node_roles = v[:roles].map{|x| x.to_sym}
        node_roles << v[:type].to_sym if v[:type]
        n = {:name => k.to_s, :host => v[:topology_hostname], :roles => node_roles}
        nodes << n
        default_role_nodes << n unless v[:no_default_role]
        task v[:topology_name] do
          server n[:host], *node_roles if n[:host]
          load_cap_override env
        end
        node_roles.each do |r|
          roles_map[r] = [] unless roles_map[r]
          roles_map[r] << n
        end
      end
      roles_map.each do |r, v|
        task "#{env}_#{r}" do
          v.each do |k|
            server k[:host], *(k[:roles]) if k[:host]
            load_cap_override env
          end
        end
      end
      task "#{env}_default_role" do
        default_role_nodes.each do |k|
          server k[:host], *(k[:roles])
          load_cap_override env
        end
      end
      task env do
        nodes.each do |k|
          server k[:host], *(k[:roles]) if k[:host]
          load_cap_override env
        end
      end
    end
  end

  on :load, "load_topology"

  def load_cap_override env
    TOPOLOGY[env][:cap_override].each do |k, v|
      set k, v
    end if TOPOLOGY[env][:cap_override]
  end

end