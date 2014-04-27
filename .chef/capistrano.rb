
puts "target needs to be specified using the -S target=<remote_host> option\n\n" unless exists?(:target)
puts "node needs to be specified using the -S node=<dna> option\n\n" unless exists?(:node)
role :target, target if exists?(:target)

cwd = File.expand_path(File.join(File.dirname(__FILE__), '..', 'chef'))
chef_dir = '/var/chef-solo'
dna_dir = '/etc/chef'
ohai_version = '7.0.2'
chef_version = "11.12.2"

namespace :chef do
  desc "Bootstrap your server to enable Chef-Solo"
  task :bootstrap, :roles => :target do
    install.requirements
    install.chef
    install.chef_repo
    install.dna
    solo
  end
  
  namespace :install do
    
    task :requirements, :roles => :target do
      ruby
    end
    
    task :ruby, :roles => :target do
      sudo 'apt-get update'
      sudo 'sudo apt-get install -y git-core curl zlib1g-dev build-essential libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev'
      sudo 'sudo apt-get install -y ruby ruby-dev rdoc ri irb wget ssl-cert'
      sudo 'apt-get -y install vim'
      run "if [ ! -e /usr/local/etc/openssl/certs/cacert.pem ]; then mkdir -p /usr/local/etc/openssl/certs; wget --directory-prefix /usr/local/etc/openssl/certs http://curl.haxx.se/ca/cacert.pem; fi"
    end

    desc "Install Chef and Ohai gems as root"
    task :chef, :roles => :target do
      {
        "ohai" => ohai_version,
        "chef" => chef_version,
      }.each do |gem_name,gem_version|
        sudo_env "gem uninstall #{gem_name} --version '>#{gem_version}'"
        sudo_env "gem install #{gem_name} -v #{gem_version} --no-ri --no-rdoc"
        sudo_env "gem cleanup #{gem_name}"
      end
    end

    desc "Install Cookbook Repository from cwd"
    task :chef_repo, :roles => :target do
      run 'aptitude install -y rsync'
      run "mkdir -m 0775 -p #{chef_dir}"
      reinstall_chef_repo
    end  
    
    desc "Install ./dna/*.json for specified node"
    task :dna, :roles => :target do
      run 'aptitude install -y rsync'
      run "mkdir -m 0775 -p #{dna_dir}"
      put %Q(file_cache_path "#{chef_dir}"
cookbook_path ["#{chef_dir}/cookbooks", "#{chef_dir}/site-cookbooks"]
role_path "#{chef_dir}/roles"
ssl_verify_mode :verify_peer), "#{dna_dir}/solo.rb", :via => :scp, :mode => "0644"
      reinstall_dna
    end
      
  end

  desc "Re-install Cookbook Repository from cwd"
  task :reinstall_chef_repo, :roles => :target do
    rsync cwd + '/', chef_dir
  end

  desc "Re-install ./dna/*.json for specified node"
  task :reinstall_dna, :roles => :target do
    rsync "#{cwd}/dna/#{node}.json", "#{dna_dir}/dna.json"
  end

  desc "Execute Chef-Solo"
  task :solo, :roles => :target do
    sudo_env "chef-solo -c #{dna_dir}/solo.rb -j #{dna_dir}/dna.json -l info -N #{node}"
  end

  desc "Reinstall and Execute Chef-Solo"
  task :resolo, :roles => :target do
    reinstall_chef_repo
    reinstall_dna
    solo
  end

  desc "Cleanup, Reinstall, and Execute Chef-Solo"
  task :clean_solo, :roles => :target do
    cleanup
    install_chef
    install_chef_repo
    install_dna
    solo
  end

  desc "Remove all traces of Chef"
  task :cleanup, :roles => :target do
    sudo "rm -rf #{dna_dir} #{chef_dir}"
    sudo_env 'gem uninstall -ax chef ohai'
  end
  
  desc "Check if the target needs a bootstrap"
  task :check_bootstrap, :roles => :target do
    begin
      sudo "gem list chef -i"
    rescue Capistrano::CommandError
      puts "Chef can't be found you should bootstrap"
      exit 1
    end
  end
  
end


# helpers
def sudo_env(cmd)
  run "#{sudo} -i #{cmd}"
end

def rsync(from, to, port = "22")
  find_servers_for_task(current_task).each do |server|
    puts `rsync -avz --delete -e "ssh -p#{port}" "#{from}" "#{user}@#{server}:#{to}" \
      --exclude ".svn" --exclude ".git" --exclude "Test Restraunt.vdi"` #Remove Test Restraunt exclude
  end
end
