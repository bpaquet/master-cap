
Capistrano::Configuration.instance.load do

  namespace :old do

    task :migrate_chef11 do
      set :user, chef_user

      env = check_only_one_env
      run "test -d /etc/chef"

      top.chef.install
      top.chef.generate_local_json

      run_root "[ ! -f /var/chef/local_storage.yml ] || mv /var/chef/local_storage.yml /opt/master-chef/var/local_storage.yml"
      run_root "rm -rf /etc/chef /var/chef /home/chef/.rbenv"
    end

  end

end
