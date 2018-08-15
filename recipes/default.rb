#
# Cookbook:: apache
# Recipe:: default
#
# Copyright:: 2018, The Authors, All Rights Reserved.
platform = node['platform']

if platform == 'centos' || platform == 'fedora'
  %w(expat-devel openssl-devel pcre-devel bzip2-devel libcurl-devel libxml2-devel libpng-devel libtool mariadb mariadb-server mariadb-devel).each do |p|
    package p do
      action :install
    end
  end
  execute 'Open up MariaDB' do
    command 'perl -pi -e "s/#bind-address=0.0.0.0/bind-address=0.0.0.0/g" /etc/my.cnf.d/mariadb-server.cnf | tee -a /tmp/update-conf'
    not_if { File.exist?('/tmp/update-conf') }
  end
elsif platform == 'ubuntu' || platform == 'debian'
  %w(libexpat1-dev libssl-dev libpcre++-dev libxml++2.6-dev libtool-bin libbz2-dev libcurl4-nss-dev libpng-dev default-mysql-client default-mysql-server default-libmysqld-dev).each do |p|
    package p do
      action :install
    end
  end
  bash 'Open Up MySQL' do
    code <<-EOH
    echo '[mysqld]' >> /etc/mysql/my.cnf
    echo 'bind-address=0.0.0.0' >> /etc/mysql/my.cnf
    touch /tmp/mysqld-done
    EOH
    action :run
    not_if { File.exist?('/tmp/mysqld-done') }
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

remote_file "/tmp/#{node['php']}.tar.bz2" do
  source "http://php.net/get/#{node['php']}.tar.bz2/from/this/mirror"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
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

remote_file "/tmp/phpMyAdmin-#{node['phpmaver']}-english.tar.gz" do
  source "https://files.phpmyadmin.net/phpMyAdmin/#{node['phpmaver']}/phpMyAdmin-#{node['phpmaver']}-english.tar.gz"
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

bash 'Extract phpMyAdmin to htdocs' do
  code <<-EOH
  tar -zxvf /tmp/phpMyAdmin-#{node['phpmaver']}-english.tar.gz -C #{node['apachehome']}/htdocs/
  mv #{node['apachehome']}/htdocs/phpMyAdmin-#{node['phpmaver']}-english #{node['apachehome']}/htdocs/phpMyAdmin
  EOH
  action :run
  not_if { File.exist?("#{node['apachehome']}/htdocs/phpMyAdmin") }
end

template "#{node['apachehome']}/htdocs/phpMyAdmin/config.inc.php" do
  source 'config.inc.php.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables ({
    :hostname  => node['hostname'],
    :ipaddress => node['ipaddress'],
    :portnum   => node['portnum'],
    :pmaschema => node['pmaschema'],
    :admin     => node['admin'],
    :adminpass => node['adminpass'],
    :pmauser   => node['pmauser'],
    :pmapass   => node['pmapass'],
  })
  action :create
end

if platform == 'centos' || platform == 'fedora'
  service 'mariadb' do
    action [:start, :enable]
  end
elsif platform == 'ubuntu' || platform == 'debian'
  service 'mysql' do
    action [:start, :enable]
  end
else
  log "You are runing on Platform #{node['platform']}, this platform is not supported!" do
    level :info
  end
end

cookbook_file '/tmp/create_tables.sql' do
  source 'create_tables.sql'
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end

template '/tmp/pma.sql' do
  source 'pma.sql.erb'
  owner 'root'
  group 'root'
  mode '0755'
  variables ({
    :pmaschema => node['pmaschema'],
    :pmauser   => node['pmauser'],
    :pmapass   => node['pmapass'],
    :fqdn      => node['fqdn'],
    :admin     => node['admin'],
    :adminpass => node['adminpass'],
  })
  action :create
end

bash 'Create phpMyAdmin tables and Users' do
  code <<-EOH
  mysql < /tmp/create_tables.sql
  mysql < /tmp/pma.sql
  touch /tmp/db-done
  EOH
  action :run
  not_if { File.exist?('/tmp/db-done') }
end

execute 'Start Apache' do
  command "#{node['apachehome']}/bin/apachectl start | tee -a /tmp/apache-started"
  action :run
  not_if { File.exist?('/tmp/apache-started') }
end
