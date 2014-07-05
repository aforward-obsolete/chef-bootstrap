
if ENV['TARGET'].nil? || ENV['NODE'].nil?
  puts "Please specify target '-s target=<remote_host>', e.g. '-s target=10.0.0.3'\n" if ENV['TARGET'].nil?
  puts "Please specify node '-s node=<dna>', e.g. '-s node=bare'\n" if ENV['NODE'].nil?
  puts ""
  exit
end

role :target, "root@#{ENV['TARGET']}"
set :stage, :production

cwd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'chef'))
chef_dir = '/var/chef-solo'
dna_dir = '/etc/chef'
ohai_version = '7.0.2'
chef_version = "11.12.2"

namespace :chef do
  desc "Bootstrap your server to enable Chef-Solo"

  task :bootstrap do
    invoke 'chef:install:requirements'
    invoke 'chef:install:chef'
    invoke 'chef:install:chef_repo'
    invoke 'chef:install:dna'
    invoke 'chef:solo'
  end

  namespace :install do

    task :requirements do
      invoke 'chef:install:ruby'
    end

    task :ruby do
      on roles(:target), in: :sequence, wait: 1 do
        execute 'apt-get update'
        # execute 'apt-get install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev wget ssl-cert'
        # execute 'apt-get -y install vim'
        execute 'apt-get install -y ruby1.9.1 ruby1.9.1-dev rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev'
        execute 'update-alternatives --config ruby'
        execute 'update-alternatives --config gem'
        execute 'apt-get install -y wget ssl-cert'

        if test("[ ! -e /usr/local/etc/openssl/certs/cacert.pem ]")
          execute "mkdir -p /usr/local/etc/openssl/certs"
          execute "wget --directory-prefix /usr/local/etc/openssl/certs http://curl.haxx.se/ca/cacert.pem"
        end
        # execute "if [ ! -e /usr/local/etc/openssl/certs/cacert.pem ]; then mkdir -p /usr/local/etc/openssl/certs; wget --directory-prefix /usr/local/etc/openssl/certs http://curl.haxx.se/ca/cacert.pem; fi"
      end
    end

    desc "Install Chef and Ohai gems as root"
    task :chef do
      on roles(:target), in: :sequence, wait: 1 do
        {
          "ohai" => ohai_version,
          "chef" => chef_version,
        }.each do |gem_name,gem_version|
          if test("gem list #{gem_name} --version '>#{gem_version}' -i")
            execute "gem uninstall #{gem_name} --version '>#{gem_version}'"
          end
          unless test("gem list #{gem_name} --version #{gem_version} -i")
            execute "gem install #{gem_name} -v #{gem_version} --no-ri --no-rdoc"
            execute "gem cleanup #{gem_name}"
          end
        end
      end
    end

    desc "Install Cookbook Repository from cwd"
    task :chef_repo do
      on roles(:target), in: :sequence, wait: 1 do
        execute 'aptitude install -y rsync'
        execute "mkdir -m 0775 -p #{chef_dir}"
      end
      invoke 'chef:reinstall_chef_repo'
    end

    desc "Install ./dna/*.json for specified node"
    task :dna do
      on roles(:target), in: :sequence, wait: 1 do
        execute 'aptitude install -y rsync'
        execute "mkdir -m 0775 -p #{dna_dir}"
        io = StringIO.new(%Q(file_cache_path "#{chef_dir}"
cookbook_path ["#{chef_dir}/cookbooks", "#{chef_dir}/site-cookbooks"]
role_path "#{chef_dir}/roles"
ssl_verify_mode :verify_peer))
        upload! io, "#{dna_dir}/solo.rb", {:via => :scp, :mode => "0644"}
      end
      invoke 'chef:reinstall_dna'
    end

  end

  desc "Re-install Cookbook Repository from cwd"
  task :reinstall_chef_repo do
    run_locally do
      execute "rsync -avz --delete -e \"ssh -p22\" \"#{cwd}/\" \"root@#{ENV["TARGET"]}:#{chef_dir}\" --exclude \".svn\" --exclude \".git\""
    end
  end

  desc "Re-install ./dna/*.json for specified node"
  task :reinstall_dna do
    on roles(:target), in: :sequence, wait: 1 do
      upload! "#{cwd}/dna/#{ENV["NODE"]}.json", "#{dna_dir}/dna.json"
    end
  end

  desc "Execute Chef-Solo"
  task :solo do
    on roles(:target), in: :sequence, wait: 1 do
      execute "chef-solo -c #{dna_dir}/solo.rb -j #{dna_dir}/dna.json -l info -N #{ENV["NODE"]}"
    end
  end

  desc "Reinstall and Execute Chef-Solo"
  task :resolo do
    invoke 'chef:reinstall_chef_repo'
    invoke 'chef:reinstall_dna'
    invoke 'chef:solo'
  end

  desc "Cleanup, Reinstall, and Execute Chef-Solo"
  task :clean_solo do
    invoke 'chef:cleanup'
    invoke 'chef:install_chef'
    invoke 'chef:install_chef_repo'
    invoke 'chef:install_dna'
    invoke 'chef:solo'
  end

  desc "Remove all traces of Chef"
  task :cleanup do
    on roles(:target), in: :sequence, wait: 1 do
      execute "rm -rf #{dna_dir} #{chef_dir}"
      execute 'gem uninstall -ax chef ohai'
    end
  end

  desc "Check if the target needs a bootstrap"
  task :check_bootstrap do
    on roles(:target), in: :sequence, wait: 1 do
      begin
        sudo "gem list chef -i"
      rescue Capistrano::CommandError
        puts "Chef can't be found you should bootstrap"
        exit 1
      end
    end
  end

end
