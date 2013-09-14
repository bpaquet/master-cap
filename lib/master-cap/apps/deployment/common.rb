
require 'json'

Capistrano::Configuration.instance.load do

  set :deploy_via, :remote_cache
  set :copy_exclude, ['.git']
  set :use_sudo, false
  set :ssh_options, { :forward_agent => true }

  JSON.parse(File.read(ENV['TOPOLOGY'])).each do |server_name, roles|
    server server_name, *roles
  end

  def env_http_proxy
    result = {}
    if exists? :http_proxy
      result['http_proxy'] = http_proxy
      result['https_proxy'] = http_proxy
    end
    if exists? :no_proxy
      result['NO_PROXY'] = no_proxy
    end
    result
  end

  ENV['LOAD_INTO_CAP'].split(':').each do |f|
    # puts "Load #{f}"
    load f
  end

end

