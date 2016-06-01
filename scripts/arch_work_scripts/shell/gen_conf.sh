#!/bin/bash



env="prod uat dev"
emplacement="default fqdn"


for val in prod uat dev
do
if [ ! -e "files/$val" ]
	then 
	mkdir files/$val
	mkdir files/$val/default
	mkdir files/$val/fqdn

case "$val" in 

prod|uat)

for server in $(dig +short cron-job-core-${val}.e-merchant.local | xargs -n 1 dig +short -x | awk '$1 !~ /^cron00/ {gsub(/\.$/, "", $1); print $1}')
do
mkdir files/$val/fqdn/$server
done
;;

dev)
for server in $(dns_search cron |grep dev |grep -v ipmi|grep -v vip |grep -v "^10" |awk '{print$1}')
do
mkdir files/$val/fqdn/$server
done
;;
esac
fi

if [ ! -e "files/$val/default" ] 
then 
mkdir files/$val/default 
fi 

if [ ! -e "files/$val/fqdn" ] 
then 
mkdir files/$val/fqdn
fi

case "$val" in 

prod|uat)

for server in $(dig +short cron-job-core-${val}.e-merchant.local | xargs -n 1 dig +short -x | awk '$1 !~ /^cron00/ {gsub(/\.$/, "", $1); print $1}')
        do
        if [ ! -e "files/$val/fqdn/$server" ]
        then 
        mkdir files/$val/fqdn/$server
        fi 
	done
;;
dev)

for server in $(dns_search cron |grep dev |grep -v ipmi|grep -v vip |grep -v "^10" |awk '{print$1}')
do
if [ ! -e "files/$val/fqdn/$server" ]
then 
mkdir files/$val/fqdn/$server
fi 
done

;;

esac 



done




for val in $env 

do
if [ -e "files/$val" ]
then
if [ ! -e "files/$val/default/authkeys" ] 
then 
echo "auth 1" > files/$val/default/authkeys
pass=`pwgen -c 16 |head -1 |awk '{print$1}'`
echo "1 sha1 "${pass}"" >> files/$val/default/authkeys
fi
cat files/default/ha.cf_base|grep -v "^#" > files/$val/default/ha.cf
	for server in $(ls files/$val/fqdn)
	do
	echo "ucast eth0 `dig $server +short` " >> files/$val/default/ha.cf
        name=`ssh $server " uname -n "`
	echo "node $name" >> files/$val/default/ha.cf
        ip_addr_ping=`ssh $server "cat /etc/network/interfaces" |grep gateway |awk '{print$2}'`
	done
 echo "ping $ip_addr_ping" >> files/$val/default/ha.cf
n=`ls files/$val/fqdn |wc -l`
service=`ls files/default/|grep -v "ha"`
echo "Env : $val"
echo "Nombre de serveurs cron : $n"

case $n in 
1) echo " on ne peux pas mettre en place un heartbeat avec un seul serveur !! " 
 
;;
2)
index=0
for srv in $(ls files/$val/fqdn) 
do
name=`ssh $srv "uname -n"`
list[index]="$name $service"
list_b[index]="$srv"
index=$(expr $index + 1)
done
echo ${list[1]}
echo ${list[0]}

echo ${list[1]} > files/$val/fqdn/${list_b[0]}/haresources
echo ${list[0]} > files/$val/fqdn/${list_b[1]}/haresources
;;
*)
index=0
for srv in $(ls files/$val/fqdn)
do
name=`ssh $srv "uname -n"`
list[index]="$name $service"
list_b[index]="$srv"
index=$(expr $index + 1)
done
for ((i=$(expr $n - 1); i>=0; i--))
do

echo ${list[$i]}
echo ${list[$i]} > files/$val/fqdn/${list_b[$(expr $i - 1)]}/haresources
done
;;
esac 
fi
done

