#
# Cookbook:: apache
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
include_recipe 'tar::default'

platform = node['platform']

if platform == 'centos' || platform == 'fedora'
  %w(postgresql-devel expat-devel openssl-devel pcre-devel bzip2-devel libcurl-devel libxml2-devel libpng-devel libtool mariadb-devel).each do |p|
    package p do
      action :install
      ignore_failure true
    end
  end
elsif platform == 'ubuntu' || platform == 'debian'
  %w(default-libmysqlclient-dev default-libmysqld-dev postgresql-server-dev-all libexpat1-dev libssl-dev libpcre++-dev libxml++2.6-dev libtool-bin libbz2-dev libcurl4-nss-dev libpng-dev).each do |p|
    package p do
      action :install
      ignore_failure true
    end
  end
else
  log "You are runing on Platform #{node['platform']}, this platform is not supported!" do
    level :info
  end
end

tar_package "http://www-us.apache.org/dist/apr/apr-#{node['aprver']}.tar.gz" do 
  prefix "#{node['apachehome']}"
  creates "#{node['apachehome']}/bin/apr-1-config"
end

tar_package "http://www-us.apache.org/dist/apr/apr-util-#{node['apruver']}.tar.gz" do 
  prefix "#{node['apachehome']}"
  configure_flags ["--with-apr=#{node['apachehome']}/bin/apr-1-config"]
  creates "#{node['apachehome']}/bin/apru-1-config"
end

bash 'Register the expat libapru libraries' do
  code <<-EOH
  libtool --finish #{node['apachehome']}/lib
  touch /tmp/libapru-done
  EOH
  action :run
  not_if { File.exist?('/tmp/libapru-done') }
end

tar_package "http://www-us.apache.org/dist/httpd/httpd-#{node['httpver']}.tar.gz" do
  prefix "#{node['apachehome']}"
  configure_flags [
    '--enable-ssl',
    '--enable-proxy',
    '--enable-modules=all',
    '--enable-mods-shared=all',
    '--enable-module=so',
    '--enable-proxy-http',
    '--enable-proxy-balancer',
    '--enable-proxy-ajp',
    '--with-ssl',
    '--with-mpm=prefork',
    "--with-apr=#{node['apachehome']}/bin/apr-1-config",
    "--with-apr-util=#{node['apachehome']}/bin/apu-1-config",
    '--enable-cgi',
  ]
  creates "#{node['apachehome']}/bin/httpd"
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

tar_package "http://php.net/get/php-#{node['phpver']}.tar.gz/from/this/mirror" do
  prefix '/usr/local'
  archive_name "php-#{node['phpver']}.tar.gz"
  configure_flags [
    '--with-zlib',
    '--enable-zip',
    '--enable-wddx',
    '--enable-sysvmsg',
    '--enable-sockets',
    '--enable-soap',
    '--enable-shmop',
    '--enable-embedded-mysqli',
    '--enable-mbstring',
    '--with-mhash',
    '--with-gettext',
    '--with-gd',
    '--enable-ftp',
    '--enable-exif',
    '--enable-dba',
    '--with-curl',
    '--enable-calendar',
    '--with-bz2',
    '--enable-bcmath',
    '--enable-static',
    '--with-mysqli',
    '--with-pgsql',
    "--with-apxs2=#{node['apachehome']}/bin/apxs",
  ]
  creates '/usr/local/bin/php'
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

service 'apache' do
  action [:start, :enable]
end

