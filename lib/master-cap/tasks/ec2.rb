
Capistrano::Configuration.instance.load do

  namespace :ec2 do

    task :bootstrap_ubuntu_step1 do
      set :user, "ubuntu"
      run_root "grep chef /etc/passwd || useradd chef --home /home/chef --shell /bin/bash"
      run_root "grep chef /etc/sudoers || echo \"chef ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
      run_root "mkdir -p /home/chef && cp -r /home/ubuntu/.ssh /home/chef/.ssh && chown -R chef /home/chef/"
      run_root "apt-get install curl"
    end

    task :bootstrap_ubuntu_step2 do
      run_root "rm -rf /home/ubuntu /etc/sudoers/* && userdel ubuntu || true"
    end

  end

end