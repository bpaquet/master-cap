
require 'yaml'
require 'erubis'
require 'deep_merge'

Capistrano::Configuration.instance.load do

  topology_directory = fetch(:topology_directory, 'topology')

  task :load_topology_directory do
    Dir["#{topology_directory}/*.yml"].each do |f|
      next if f =~ /.inc.yml/
      env = File.basename(f).split('.')[0]
      puts "Loading file #{f}"
      TOPOLOGY[env] = YAML.load(File.read(f))

      load_included_files env, topology_directory

      nodes = []
      roles_map = Hash.new { |hash, key| hash[key] = [] }
      TOPOLOGY[env][:topology].each do |k, v|
        v[:topology_name] = translation_strategy.node_name(env, k, v, TOPOLOGY[env])
        v[:topology_hostname] = begin translation_strategy.node_hostname(env, k, v, TOPOLOGY[env]) rescue nil end
        next unless v[:topology_hostname]
        node_roles = []
        node_roles += v[:roles].map{|x| x.to_sym} if v[:roles]
        node_roles << v[:type].to_sym if v[:type]
        n = {:name => k.to_s, :host => v[:topology_hostname], :roles => node_roles}
        nodes << n

        task v[:topology_name] do
          server n[:host], *node_roles if n[:host]
          load_cap_override env
        end

        node_roles.each do |r|
          roles_map[r] << n
        end

      end

      roles_map.each do |r, v|
        task "role-#{r}-#{env}" do
          v.each do |k|
            server k[:host], *(k[:roles]) if k[:host]
            load_cap_override env
          end
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

  def load_cap_override env
    TOPOLOGY[env][:cap_override].each do |k, v|
      set k, v
    end if TOPOLOGY[env][:cap_override]
  end

  def load_included_files env, topology_directory
    return unless TOPOLOGY[env][:includes]
    TOPOLOGY[env][:includes][:files].each do |f|
      template = nil
      begin
        file = "#{topology_directory}/#{f}"
        puts "Loading file #{file}"
        params = TOPOLOGY[env][:includes][:params] || {}
        template = YAML.load(::Erubis::Eruby.new(File.read(file)).result(params))
      rescue Exception => e
        puts "ERROR : Error while reading [#{file}]"
        raise e
      end
      TOPOLOGY[env].deep_merge!(template, :merge_hash_arrays => true)
    end
    TOPOLOGY[env].delete :includes
  end

end
