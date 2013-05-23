require 'tempfile'
require 'json'
require 'yaml'

require File.join(File.dirname(__FILE__), 'git_repos_manager.rb')

Capistrano::Configuration.instance.load do

  namespace :chef do

    set :master_chef_path, fetch(:master_chef_path, '../master-chef')
    set :git_repos_manager, Object.const_get(fetch(:git_repos_manager_class, 'EmptyGitReposManager')).new(self)

    task :generate_local_json do
      set :user, chef_user
      env = check_only_one_env
      find_nodes(:roles => chef_role).each do |env, node, s|
        r = []
        r += (TOPOLOGY[env][:default_role_list] || []) unless node[:no_default_role]
        r += node[:roles]
        json = JSON.pretty_generate({
          :repos => {
            :git => git_repos_manager.list,
          },
          :run_list => r.map{|x| "role[#{x}]"},
          :node_config => {
            :topology_node_name => node[:topology_name]
          }
        })
        puts json
        f = Tempfile.new File.basename("local_json_#{name}")
        f.write json
        f.close
        upload_to_root f.path, "/etc/chef/local.json", {:hosts => [s]}
      end
      git_repos_manager.list.each do |git_repo|
        if git_repo =~ /^.+@.+:.+\.git$/
          run "sudo ssh -o StrictHostKeyChecking=no #{git_repo.split(':')[0]} echo toto > /dev/null 2>&1 || true ", :roles => chef_role
        end
      end
    end

    def get_prefix
      prefix = ""
      prefix += "http_proxy=#{http_proxy} https_proxy=#{http_proxy}" if exists? :http_proxy
      prefix
    end

    task :upload_git_tag_override, :roles => :linux_chef do
      set :user, chef_user
      env = check_only_one_env

      git_tag_override = git_repos_manager.compute_override(env)

      if git_tag_override
        f = Tempfile.new File.basename("git_tag_override")
        f.write JSON.dump(git_tag_override)
        f.close

        upload_to_root f.path, "/etc/chef/local.json.git_tag_override"
      end

    end

    task :upload_topology, :roles => :linux_chef  do
      set :user, chef_user
      env = check_only_one_env

      f = Tempfile.new File.basename("topology_env")
      f.write YAML.dump(TOPOLOGY[env])
      f.close
      upload_to_root f.path, "/etc/chef/topology.yml"
    end

    task :default, :roles => chef_role  do
      set :user, chef_user
      upload_topology
      upload_git_tag_override
      run "#{get_prefix} /etc/chef/update.sh"
    end

    task :stack, :roles => chef_role  do
      set :user, chef_user
      run "sudo cat /var/chef/cache/chef-stacktrace.out"
    end

    task :purge_cache, :roles => chef_role do
      set :user, chef_user
      run "sudo rm -rf /var/chef/cache/git_repos"
    end

    task :local, :roles => chef_role  do
      set :user, chef_user
      upload_topology
      find_servers(:roles => chef_role).each do |x|
        prefix = ""
        prefix = "PROXY=#{http_proxy}" if exists? :http_proxy
        command = "sh -c \"#{prefix} #{master_chef_path}/runtime/chef_local.rb #{x} #{git_repos_manager.compute_local_path}\""
        abort unless system command
      end
    end

  end

end