#!/bin/bash

## vars : 
vg_size_file=$(mktemp /tmp/vgsize.XXXX)
prometheus_file_tmp="/var/lib/prometheus/node-exporter/lvm_thin_used_pct.prom.$$"
prometheus_file="/var/lib/prometheus/node-exporter/lvm_thin_used_pct.prom"

#clean prom file
> $prometheus_file

# retrieve pct free on vgs :
/usr/sbin/lvs |grep "<" |awk '{print $2, $5}' > $vg_size_file

echo "# HELP node_vg_size_pct_used Volumegroup size in pct."  >> $prometheus_file_tmp
echo "# TYPE node_vg_size_pct_used gauge" >> $prometheus_file_tmp     
while read vg pct
do 
  echo "node_vg_size_pct_used{vgname=\""$vg"\",nodename=\""$(hostname)"\"} $pct" >> $prometheus_file_tmp
done < $vg_size_file

# cleanup tmp file and rename the temp prom file too : 
rm $vg_size_file
mv $prometheus_file_tmp $prometheus_file

