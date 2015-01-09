require 'capistrano/dsl/unicorn_paths'
require 'capistrano/unicorn_nginx/helpers'

include Capistrano::UnicornNginx::Helpers
include Capistrano::DSL::UnicornPaths

namespace :load do
  task :defaults do
    set :unicorn_service, -> { "unicorn_#{fetch(:application)}_#{fetch(:stage)}" }
    set :templates_path, 'config/deploy/templates'
    set :unicorn_initd, => { unicorn_initd_file }
    set :unicorn_pid, -> { unicorn_default_pid_file }
    set :unicorn_config, -> { unicorn_default_config_file }
    set :unicorn_workers, 2
    set :unicorn_tcp_listen_port, 8080
    set :unicorn_use_tcp, -> { roles(:app, :web).count > 1 } # use tcp if web and app nodes are on different servers
    set :unicorn_app_env, -> { fetch(:rails_env) || fetch(:stage) }
    # set :unicorn_user # default set in `unicorn:defaults` task

    set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids')
  end
end

namespace :unicorn do

  task :defaults do
    on roles :app do
      set :unicorn_user, fetch(:unicorn_user, deploy_user)
    end
  end

  desc 'Setup Unicorn initializer'
  task :setup_initializer do
    on roles :app do
      sudo_upload! template('unicorn_init.erb'), unicorn_initd_file
      execute :chmod, '+x', unicorn_initd_file
      sudo "chkconfig", "--add", fetch(:unicorn_service)
      sudo "chkconfig", fetch(:unicorn_service), "on"
    end
  end

  desc 'Setup Unicorn app configuration'
  task :setup_app_config do
    on roles :app do
      execute :mkdir, '-pv', File.dirname(fetch(:unicorn_config))
      upload! template('unicorn.rb.erb'), fetch(:unicorn_config)
    end
  end

  %w[start stop restart].each do |command|
    desc "#{command} unicorn"
    task command do
      on roles :app do
        execute :service, fetch(:unicorn_service), command
      end
    end
  end

  before :setup_initializer, :defaults

end

namespace :deploy do
  task :restart do
    execute fetch(:unicorn_initd), "upgrade"
  end

  after :publishing, 'unicorn:restart'
end

desc 'Server setup tasks'
task :setup do
  invoke 'unicorn:setup_initializer'
  invoke 'unicorn:setup_app_config'
end
