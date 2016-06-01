#!/bin/sh

DIRNAME=$(dirname $0)

for site in vit dc3; do
	scp $DIRNAME/collectd-confgen.yaml root@poll01.monit.common.prod.$site.e-merchant.net:
	ssh -l root poll01.monit.common.prod.$site.e-merchant.net "/root/collectd-confgen -c collectd-confgen.yaml > /etc/collectd/snmp/hosts/e-merchant && /etc/init.d/collectd restart"
done
