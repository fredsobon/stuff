#!/bin/bash
. /mcorp/script/fonctions/scripts_imon.sh

# 

DISTRIB=/ilius/scripts/distrib
WGET=/usr/bin/wget
PORT=$1

# 
if [ -z $PORT ]; then 
echo "please  provide port in arg !"
exit 1
fi



do_check()
{
	(
		count=$(${WGET} --timeout=10 -q -O- http://$1.frontend:${PORT}/check/ok.php) 
		echo "$count"
		if [ -z ${count} ] ; then
		     echo "ko"
		else 
		     echo "ok"  
		fi
	) &
}

(
	${DISTRIB} list -g front | sed -e 's/^ //' -e 's/ /\n/g' | while read host
	do
	   if [ -f "/ilius/monitors/lock/dont-monitor.$host" ]
	   then
              continue
           fi
	   do_check ${host}
	done
	wait
) | sort -n -k2 -t=

