
Capistrano::Configuration.instance.load do

  namespace :ssh_known_hosts do

    task :purge do
      exec_local "sed -i'' -e '/no hostip for proxy command/d' #{ENV['HOME']}/.ssh/known_hosts"
      find_servers.map{|s| s.host}.each do |x|
        exec_local "ssh-keygen -R #{x}"
      end
      puts "Done."
    end

  end

end