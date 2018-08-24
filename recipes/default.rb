#
# Cookbook:: apache
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
platform = node['platform']

if node.chef_environment != 'remotedb'
  include_recipe 'database'
end

if platform == 'centos' || platform == 'fedora'
  %w(expat-devel openssl-devel pcre-devel bzip2-devel libcurl-devel libxml2-devel libpng-devel libtool mariadb-devel).each do |p|
    package p do
      action :install
    end
  end
elsif platform == 'ubuntu' || platform == 'debian'
  %w(libexpat1-dev libssl-dev libpcre++-dev libxml++2.6-dev libtool-bin libbz2-dev libcurl4-nss-dev libpng-dev).each do |p|
    package p do
      action :install
    end
  end
else
  log "You are runing on Platform #{node['platform']}, this platform is not supported!" do
    level :info
  end
end

remote_file "/tmp/#{node['apr']}.tar.bz2" do
  source "http://www-us.apache.org/dist/apr/#{node['apr']}.tar.bz2"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

bash 'Extract APR' do
  code <<-EOH
  tar -jxvf /tmp/#{node['apr']}.tar.bz2 -C /tmp
  EOH
  action :run
end

template "/tmp/#{node['apr']}/configure.sh" do
  source 'configure-apr.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :apachehome => node['apachehome'],
  })
  action :create
end

bash 'Run Apr Build' do
  code <<-EOH
  cd /tmp/#{node['apr']}
  ./configure.sh
  make && make install
  touch /tmp/build-apr
  EOH
  action :run
  not_if { File.exist?('/tmp/build-apr') }
end

remote_file "/tmp/#{node['apru']}.tar.bz2" do
  source "http://www-us.apache.org/dist/apr/#{node['apru']}.tar.bz2"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

bash 'Extract APRU' do
  code <<-EOH
  tar -jxvf /tmp/#{node['apru']}.tar.bz2 -C /tmp
  EOH
  action :run
end

template "/tmp/#{node['apru']}/configure.sh" do
  source 'configure-apru.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :apachehome => node['apachehome'],
  })
  action :create
end

bash 'Run Apru Build' do
  code <<-EOH
  cd /tmp/#{node['apru']}
  ./configure.sh
  make && make install
  touch /tmp/build-apru
  EOH
  action :run
  not_if { File.exist?('/tmp/build-apru') }
end

if platform == 'ubuntu' || platform == 'debian'
  bash 'Register the expat libapru libraries' do
    code <<-EOH
    libtool --finish #{node['apachehome']}/lib
    touch /tmp/libapru-done
    EOH
    action :run
    not_if { File.exist?('/tmp/libapru-done') }
  end
end
  
remote_file "/tmp/#{node['httpd']}.tar.bz2" do
  source "http://www-us.apache.org/dist/httpd/#{node['httpd']}.tar.bz2"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

bash 'Extract HTTPD' do
  code <<-EOH
  tar -jxvf /tmp/#{node['httpd']}.tar.bz2 -C /tmp
  EOH
  action :run
end

template "/tmp/#{node['httpd']}/configure.sh" do
  source 'configure.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :apachehome => node['apachehome'],
  })
  action :create
end

bash 'Run HTTPD Build' do
  code <<-EOH
  cd /tmp/#{node['httpd']}
  ./configure.sh
  make && make install
  touch /tmp/build-httpd
  EOH
  action :run
  not_if { File.exist?('/tmp/build-httpd') }
end

template '/etc/systemd/system/apache.service' do
  source 'apache.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables ({
    :apachehome => node['apachehome'],
  })
  action :create
  only_if { File.exist?("#{node['apachehome']}/bin/httpd") }
end

execute 'Register the new Apache Service' do
  command 'systemctl daemon-reload | tee -a /tmp/apache-service'
  action :run
  not_if { File.exist?('/tmp/apache-service') }
end

remote_file "/tmp/#{node['php']}.tar.bz2" do
  source "http://php.net/get/#{node['php']}.tar.bz2/from/this/mirror"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
  not_if { File.exist?("/tmp/#{node['php']}.tar.bz2") }
end

bash 'Extract PHP' do
  code <<-EOH
  tar -jxvf /tmp/#{node['php']}.tar.bz2 -C /tmp
  EOH
  action :run
end

template "/tmp/#{node['php']}/configure.sh" do
  source 'configure-php.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :apachehome => node['apachehome'],
  })
  action :create
end

bash 'Run PHP Build' do
  code <<-EOH
  cd /tmp/#{node['php']}
  ./configure.sh
  make && make install
  libtool --finish /tmp/#{node['php']}/lib
  touch /tmp/build-php
  EOH
  action :run
  not_if { File.exist?('/tmp/build-php') }
end

template "#{node['apachehome']}/conf/httpd.conf" do
  source 'httpd.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables ({
    :apachehome => node['apachehome'],
    :fqdn       => node['fqdn'],
    :email      => node['email'],
  })
  action :create
end

directory "#{node['confdir']}" do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template "#{node['apachehome']}/bin/rotateLog.sh" do
  source 'rotateLog.sh.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :confdir    =>  node['confdir'],
    :apachehome =>  node['apachehome'],
    :email      =>  node['email'],
  })
  action :create
end

cron 'RotateLog' do
  hour '0'
  minute '0'
  command "#{node['apachehome']}/bin/rotateLog.sh > /dev/null 2>&1"
  action :create
end

template "#{node['apachehome']}/bin/createindex.php" do
  source 'createindex.php.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :apachehome =>  node['apachehome'],
    :dbhost     =>  node['dbhost'],
    :admuser    =>  node['admuser'],
    :admpass    =>  node['admpass'],
    :dbschema   =>  node['dbschema'],
  })
  action :create
end

cron 'QueryOneIndex' do
  hour '0'
  minute '0'
  command "/usr/local/bin/php #{node['apachehome']}/bin/createindex.php > /dev/null 2>&1"
  action :create
end

service 'apache' do
  action [:start, :enable]
end

