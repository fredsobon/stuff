#!/bin/sh

echo "Removing old puppet and facter packages..."
apt-get -y remove --purge puppet puppet-common facter

echo "Updating APT source list..."
#cat >> /etc/apt/sources.list << EOF
#deb http://ubuntu.backports.e-merchant.com/ e-merchant main
#EOF

cat >> /etc/apt/preferences << EOF

Package: *
Pin: release n=e-merchant
Pin-Priority: 901

EOF

apt-get -q=10 update

echo "Installing new version of puppet and facter packages..."
apt-get -y install puppet facter

fqdn=$(hostname -f 2>/dev/null || hostname)
environ=$(echo $fqdn | cut -d \. -f3)

echo "Configuring puppet.conf, environment is $(tput bold)$environ$(tput sgr0)..."
cat > /etc/puppet/puppet.conf << EOF
####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################
########
# MAIN #
########
[main]
user=puppet
group=puppet
logdir=/var/log/puppet
vardir=/var/lib/puppet
ssldir=/var/lib/puppet/ssl
rundir=/var/run/puppet
reportdir=/var/log/puppet
factpath=\$vardir/lib/facter
#templatedir=\$confdir/templates
#prerun_command=/etc/puppet/etckeeper-commit-pre
#postrun_command=/etc/puppet/etckeeper-commit-post
pluginsync=true
document_all=true
evaltrace=true
graph=true
#reports=log,tagmail,rrdgraph,http
reports=log,store,tagmail,rrdgraph
tagmap=/etc/puppet/tagmail.conf
#reporturl = http://puppet02.tool.common.prod.vit.e-merchant.net:3000/reports/upload

#########
# AGENT #
#########
[agent]
server=vip01-slave.puppet.common.prod.vit.e-merchant.net
ca_server=ca.puppet.common.prod.vit.e-merchant.net
report=true
ignorecache=true
usecacheonfailure=false
onetime=true
summarize=true
preferred_serialization_forma=yaml
environment=$environ
EOF

echo "You can manually launch: puppetd agent --test"

exit 0
