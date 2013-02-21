
require File.join(File.dirname(__FILE__), 'misc.rb')
require File.join(File.dirname(__FILE__), 'default_translation_strategy.rb')

unless Capistrano::Configuration.respond_to?(:instance)
  abort "master-cap requires Capistrano 2"
end

TOPOLOGY = {}

Capistrano::Configuration.instance.load do

  set :chef_user, fetch(:chef_user, "chef")
  set :translation_strategy, Object.const_get(fetch(:translation_strategy_class, 'DefaultTranslationStrategy')).new

  task :check do
    find_servers(:roles => :linux_chef).sort_by{|s| s.host}.each do |s|
      env, node = find_node s.host
      begin
        exec_local_with_timeout "ssh -o StrictHostKeyChecking=no #{chef_user}@#{node[:topology_hostname]} uname > /dev/null 2>&1", fetch(:check_timeout, 10)
        puts "OK    : #{node[:topology_hostname]}"
      rescue
        puts "ERROR : Unable to join #{node[:topology_hostname]}"
      end
    end
  end

  task :ssh_cmd, :roles => :linux_chef do
    error "Please specify command with -s cmd=" unless exists? :cmd
    set :user, chef_user
    run cmd
  end

  task :show do
    ss = find_servers
    puts "Number of selected servers: #{ss.length}"
    ss.each do |s|
      env, node = find_node s.host
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

end