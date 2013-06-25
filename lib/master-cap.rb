
unless Capistrano::Configuration.respond_to?(:instance)
  abort "master-cap requires Capistrano 2"
end

require 'master-cap/helpers.rb'
require 'master-cap/git_repos_manager.rb'
require 'master-cap/translation_strategy.rb'
require 'master-cap/topology.rb'
require 'master-cap/tasks.rb'
