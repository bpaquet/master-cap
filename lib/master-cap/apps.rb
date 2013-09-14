
APPS={}

Capistrano::Configuration.instance.load do

  set :apps_cap_directory, fetch(:apps_cap_directory, "deployment")

  namespace :apps do

    task :load_apps do
      apps_list = {}
      TOPOLOGY.each do |name, env|
        if env[:apps]
          env[:apps].each do |n, a|
            apps_list[n] = [] unless apps_list[n]
            apps_list[n] << name
            APPS["#{name}_#{n}"] = {:config => a, :env => name, :name => n}
          end
        end
      end
      apps_list.keys.each do |x|

        namespace x do

          task :deploy do
            env = check_only_one_env
            get_app(env, x).deploy
          end

          task :force_deploy do
            env = check_only_one_env
            get_app(env, x).force_deploy
          end

          task :versions do
            env = check_only_one_env
            get_app(env, x).versions
          end

        end
      end

    end

    task :deploy_all do
      env = check_only_one_env
      APPS.keys.sort.each do |x|
        get_app(env, APPS[x][:name]).deploy if APPS[x][:env] == env
      end
    end

    task :force_deploy_all do
      env = check_only_one_env
      APPS.keys.sort.each do |x|
        get_app(env, APPS[x][:name]).force_deploy if APPS[x][:env] == env
      end
    end

    def get_app env, name
      unless APPS["#{env}_#{name}"][:apps]
        clazz = "Apps#{APPS["#{env}_#{name}"][:config][:type].to_s.capitalize}"
        begin
          Object.const_get clazz
        rescue
          require "master-cap/apps/#{APPS["#{env}_#{name}"][:config][:type]}.rb"
        end
        APPS["#{env}_#{name}"][:apps] = Object.const_get(clazz).new(self, name, APPS["#{env}_#{name}"][:config])
      end
      APPS["#{env}_#{name}"][:apps]
    end

  end

  on :load, "apps:load_apps"

end
