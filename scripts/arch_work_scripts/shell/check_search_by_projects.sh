#!/bin/bash
#
#set -x
#========================================================================================
# Title         : check_search_by_projects.sh
# Date          : 2014-08-01
# Author        : Abdelaziz LAMJARHJARH for E-merchant 
# Version       : 1.0
# Description   : Sonde for checking status of process search  by projects.
# 		    Remote uniquement a critical alert if all process search are down 
#========================================================================================
# Version History :
#
#========================================================================================

check_search_pertimm() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

HOST=`hostname -f`
FOLDER="/opt/pertimm/projects"

for pjt in $(ls $FOLDER);
do
	FILE_CNF=$(echo $pjt |awk -F "-" '{print$2}')
	source $FOLDER/$pjt/${FILE_CNF}.conf
	STATUS=0
	i=0
 	echo "===> Projects : $pjt : " > /tmp/${pjt}_state_S
	for srv in ${search_servers[@]} 
	do
		st=`/bin/su pertimm -c "/opt/pertimm/projects/$pjt/apps/pdk instance state -i search -H $srv |grep -A1 search  |grep state" |awk '{print$2}'`
		result[$i]=" $pjt - search on `dig -x $srv +short` : $st "
		i=$(expr $i + 1)
	done
	n=$(expr $i - 1)	
	for j in $(seq 0 $n) 
	do
		echo ${result[$j]} >> /tmp/${pjt}_state_S
	done
val=`grep -c started /tmp/${pjt}_state_S`

m=$(expr $n + 1)
if [ "$val" = "0" ]; then
	STATUS=$STATE_CRITICAL
	MESSAGE="CRITICAL - $pjt -  All SEARCH ARE DOWN !"
elif [ "$val" != "$m" ]; then 
	 STATUS=$STATE_WARNING
	 MESSAGE="WARNING - $pjt - AT LEAST ONE OF SEARCH IS UP "
else
	STATE=$STATE_OK
        MESSAGE="OK - $pjt - ALL SEARCH ARE UP"
fi

echo $MESSAGE >> /tmp/${pjt}_state_S
done

echo "=====================  RAPPORT  `date "+%a %d %b %Y %H:%M:%S" ` ========================" > /tmp/rapport_Search
for pjt in $(ls $FOLDER);
do
cat /tmp/${pjt}_state_S >> /tmp/rapport_Search
done

valeur=` grep -c CRITICAL /tmp/rapport_Search `
war=`grep -c WARNING /tmp/rapport_Search `
if [ "$valeur" != "0" ]; then
	STATUS=$STATE_CRITICAL
	MESSAGE=`cat /tmp/rapport_Search|grep CRITICAL` 
elif [ "$war" != "0" ]; then
	STATUS=$STATE_WARNING
	MESSAGE=`cat /tmp/rapport_Search|grep stopped`
else
	MESSAGE="OK - ALL SEARCH ARE UP"
fi

return $STATUS
return $MESSAGE
}

check_search_pertimm
