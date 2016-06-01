#!/usr/bin/env bash
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/usrlocal/files/fqdn/app01.log.common.prod.vit.e-merchant.net/bin/del_index.sh $

# This script aims to preserve space disk for logstash; by deleting "old" indices.After his an optimize operation is launched 


daysback=3
start=5
end=$(expr $start \+ $daysback)

if [ $? -eq 0 ]; then
    for i in $(seq $start $end); do
	for h in $(seq -f '%02.0f' 0 23); do
        	d=$(date --date "$i days ago" +"%Y.%m.%d").${h}
	        curl -XDELETE http://localhost:9200/logstash-$d > /dev/null 2>&1
	done
    done
else
    echo "Invalid number of days specified, aborting"
fi
echo " ======= OPTIMIZE ======="
curl -XPOST 'http://localhost:9200/_optimize'

