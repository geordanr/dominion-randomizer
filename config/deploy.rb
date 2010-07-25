ssh_options[:forward_agent] = true

set :application, "dominion"
set :repository,  "git://github.com/geordanr/dominion-randomizer.git"
set :deploy_to, "/var/www/rack/#{application}"

set :scm, :git
set :branch, "master"

role :web, "m.wuut.net"
role :app, "m.wuut.net"
role :db,  "m.wuut.net", :primary => true

# If you are using Passenger mod_rails uncomment this:
# if you're still using the script/reapear helper you will need
# these http://github.com/rails/irs_process_scripts

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end
