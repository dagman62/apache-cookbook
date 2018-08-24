
node.default['email'] = 'ggiacalone@example.com'
node.default['apachehome'] = '/opt/apache'
node.default['apr'] = 'apr-1.6.3'
node.default['apru'] = 'apr-util-1.6.1'
node.default['httpd'] = 'httpd-2.4.34'
node.default['php'] = 'php-7.2.8'
node.default['confdir'] = '/var/log/rotateLog'
node.default['admuser'] = 'root'
node.default['admpass'] = 'admin123!'
node.default['dbschema'] = 'dagman62'

if node.chef_environment == 'remotedb'
  node.default['dbhost'] = 'dragon.example.com'
else
  node.default['dbhost'] = node['fqdn']
end


