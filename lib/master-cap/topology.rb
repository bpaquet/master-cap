
require File.join(File.dirname(__FILE__), 'misc.rb')
require File.join(File.dirname(__FILE__), 'default_translation_strategy.rb')

unless Capistrano::Configuration.respond_to?(:instance)
  abort "master-cap requires Capistrano 2"
end

TOPOLOGY = {}

Capistrano::Configuration.instance.load do

  set :chef_role, fetch(:chef_role, :linux_chef)
  set :chef_user, fetch(:chef_user, "chef")
  set :translation_strategy, Object.const_get(fetch(:translation_strategy_class, 'DefaultTranslationStrategy')).new

  task :check do
    find_nodes(:roles => chef_role).sort_by{|env, node, s| s.host}.each do |env, node|
      begin
        exec_local_with_timeout "ssh -o StrictHostKeyChecking=no #{chef_user}@#{node[:topology_hostname]} uname > /dev/null 2>&1", fetch(:check_timeout, 10)
        puts "OK    : #{node[:topology_hostname]}"
      rescue
        puts "ERROR : Unable to join #{node[:topology_hostname]}"
      end
    end
  end

  task :ssh_cmd, :roles => chef_role do
    error "Please specify command with -s cmd=" unless exists? :cmd
    set :user, chef_user
    run cmd
  end

  task :show do
    ss = find_nodes
    puts "Number of selected servers: #{ss.length}"
    ss.each do |env, node|
      puts "#{fill(node[:topology_name], 30)} #{fill(node[:topology_hostname], 50)} [#{node[:roles].sort.join(',')}]"
    end
  end

  def find_node node_name
    TOPOLOGY.each do |k, v|
      v[:topology].each do |name, node|
        return [k, node] if translation_strategy.node_hostname(k, name, node, v) == node_name
      end
    end
    error "Node not found #{node_name}"
  end

  def find_nodes filter = {}
    find_servers(filter).map do |s|
      env, node = find_node(s.host)
      [env, node, s]
    end
  end

  def check_only_one_env servers = nil
    servers = find_servers unless servers
    env_list = {}
    servers.each do |s|
      env, name, node = find_node(s.is_a?(String) ? s : s.host)
      env_list[env] = :toto
    end
    error "Please, do not launch this command without env" if env_list.keys.size == 0
    error "Please, do not launch this command on two env : #{env_list.keys.join(' ')}" if env_list.keys.size != 1
    env = env_list.keys.first

    check_only_one_env_callback(env, servers) if exists? :check_only_one_env_callback

    env
  end

end

require File.join(File.dirname(__FILE__), 'chef.rb')
