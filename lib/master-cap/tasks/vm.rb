require 'peach'

HYPERVISORS={}
DNS={}

Capistrano::Configuration.instance.load do

  namespace :vm do

    def peach_with_errors array
      errors = nil
      array.peach do |x|
        begin
          yield x
        rescue
          errors = $!
        end
      end
      raise errors if errors
    end

    def get_dns config
      unless DNS[:dns]
        params = config[:params] || {}
        type = config[:type]
        clazz = "Dns#{type}"
        begin
          Object.const_get clazz
        rescue
          require "master-cap/dns/#{type.underscore}.rb"
        end
        DNS[:dns] = Object.const_get(clazz).new(self, params)
      end
      DNS[:dns]
    end

    def get_hypervisor hypervisor_name
      env = check_only_one_env
      id = "#{env}_#{hypervisor_name}"
      unless HYPERVISORS[id]
        raise "Unknown hypervisor #{hypervisor_name}" unless TOPOLOGY[env][:hypervisors] && TOPOLOGY[env][:hypervisors][hypervisor_name]
        params = TOPOLOGY[env][:hypervisors][hypervisor_name][:params] || {}
        type = TOPOLOGY[env][:hypervisors][hypervisor_name][:type]
        clazz = "Hypervisor#{type.to_s.capitalize}"
        begin
          Object.const_get clazz
        rescue
          require "master-cap/hypervisors/#{type}.rb"
        end
        HYPERVISORS[id] = Object.const_get(clazz).new(self, params)
      end
      HYPERVISORS[id]
    end

    def vm_exist? hypervisor_name, name
      get_hypervisor(hypervisor_name).list.include? name
    end

    def get_vm node, hypervisor
      env = check_only_one_env
      node = node.clone
      node[:vm] = {} unless node[:vm]
      node[:vm] = TOPOLOGY[env][:default_vm].deep_merge(node[:vm]) if TOPOLOGY[env][:default_vm]
      node[:vm] = hypervisor.default_vm_config.deep_merge(node[:vm]) if hypervisor.respond_to? :default_vm_config
      node
    end

    def hyp_for_vm env, node, name
      hyp = TOPOLOGY[env][:default_vm][:hypervisor] if TOPOLOGY[env] && TOPOLOGY[env][:default_vm]
      hyp = node[:vm][:hypervisor] if node[:vm] && node[:vm][:hypervisor]
      raise "No hypervisor found for node #{name} on #{env}" unless hyp
      hyp
    end

    def no_hyp? hyp_name
      hyp_name.to_s == "none"
    end

    def hyp_list
      hypervisors = []
      find_servers(:roles => :linux_chef).each do |s|
        env, node = find_node s.host
        hypervisor_name = hyp_for_vm env, node, s
        next if no_hyp? hypervisor_name
        hypervisors << hypervisor_name unless hypervisors.include? hypervisor_name
      end
      hypervisors.sort
    end

    task :list_hyp do
      puts hyp_list
    end

    task :list_vms do
      exists, not_exists = list_vms
      puts "Existing vms"
      exists.each do |k, v|
        puts "#{k} : #{v.map{|name, vm| name}.join(' ')}"
      end
      puts "Not existing vms"
      not_exists.each do |k, v|
        puts "#{k} : #{v.map{|name, vm| name}.join(' ')}"
      end
    end

    task :dump_vm_config do
      for_all do |hyp, l|
        l.each do |vm, config|
          puts vm
          p config[:vm]
        end
      end
    end

    def list_vms
      check_only_one_env
      exists = {}
      not_exists = {}
      find_servers(:roles => :linux_chef).each do |s|
        env, node = find_node s.host
        name = node[:vm_name]
        hypervisor_name = hyp_for_vm env, node, s
        next if no_hyp? hypervisor_name
        hypervisor = get_hypervisor(hypervisor_name)
        if hypervisor.exist?(name)
          exists[hypervisor_name] ||= []
          exists[hypervisor_name] << [name, get_vm(node, hypervisor)]
        else
          not_exists[hypervisor_name] ||= []
          not_exists[hypervisor_name] << [name, get_vm(node, hypervisor)]
        end
      end
      return exists, not_exists
    end

    def go l, clear_caches, block
      peach_with_errors(l) do |hypervisor_name, l|
        hypervisor = get_hypervisor(hypervisor_name)
        if exists? :batch_size
          l.each_slice(batch_size) do |ll|
            block.call hypervisor, ll, exists?(:no_dry)
          end
        else
          block.call hypervisor, l, exists?(:no_dry)
        end
        hypervisor.clear_caches if clear_caches
      end
    end

    def for_all clear_caches = false, &block
      exists, not_exists = list_vms
      go exists.merge(not_exists), clear_caches, block
    end

    def for_existing clear_caches = false, &block
      exists, not_exists = list_vms

      not_exists.each do |hypervisor, l|
        l.each do |name, vm|
          puts "\e[31mVm #{name} does not exist on #{hypervisor}\e[0m"
        end
      end

      go exists, clear_caches, block
    end

    def for_not_existing clear_caches = false, &block
      exists, not_exists = list_vms

      exists.each do |hypervisor, l|
        l.each do |name, vm|
          puts "\e[32mVm #{name} does exist on #{hypervisor}\e[0m"
        end
      end

      go not_exists, clear_caches, block
    end

    [:start, :stop, :reboot, :info, :console].each do |cmd|
      task cmd do
        for_existing do |hyp, l, dry|
          hyp.send("#{cmd}_vms".to_sym, l, dry)
        end
      end
    end

    task :create do
      for_not_existing(true) do |hyp, l, dry|
        hyp.create_vms l, exists?(:no_dry)
      end
      top.vm.dns.update
      top.ssh_known_hosts.purge
    end

    task :delete do
      for_existing(true) do |hyp, l, dry|
        hyp.delete_vms l, exists?(:no_dry)
      end
    end

    def go_dns purge
      env = check_only_one_env
      return unless TOPOLOGY[env][:dns_provider]
      dns = get_dns TOPOLOGY[env][:dns_provider]
      list = []
      for_existing(true) do |hyp, l, dry|
        list += hyp.dns_ips l, false
        list += hyp.dns_ips TOPOLOGY[env][:topology].select{|name, node| node[:type].to_sym != :linux_chef}.map{|name, node| [name.to_s, node]}, true
      end
      for_not_existing(true) do |hyp, l, dry|
        list += hyp.dns_ips l, true
      end
      list += Hypervisor.extract_dns_ips TOPOLOGY[env][:topology].select{|name, node| node[:type].to_sym != :linux_chef}
      zones = {}
      list.select!{|l| l[:ip]}
      list.each do |l|
        raise "Unable to parse #{l[dns]}" unless l[:dns].match(/^([^\.]+)\.(.*)$/)
        z, h = $2, $1
        zones[z] = [] unless zones[z]
        zones[z] << {:ip => l[:ip], :name => h}
      end
      zones.each do |name, ll|
        next if exists?(:ignore_zones) && ignore_zones.include?(name)
        uniq_map = {}
        ll.each do |r|
          raise "Conflict on zone #{name} on #{r[:name]} : #{r[:ip]}, #{uniq_map[r[:name]]}" if uniq_map[r[:name]] && uniq_map[r[:name]] != r[:ip]
          uniq_map[r[:name]] = r[:ip]
        end
        ll = uniq_map.map{|k, v| {:name => k, :ip => v}}
        dns.sync name, ll, purge, exists?(:no_dry)
      end
    end

    namespace :dns do

      task :sync do
        go_dns true
      end

      task :update do
        go_dns false
      end

    end

  end

  namespace :dns do

    task :sync do
      top.vm.dns.sync
    end

  end

end