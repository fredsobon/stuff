#!/bin/bash

# main goal : retrieve cpu performance settings on "ProLiant Gen 9" servers  : this requires the uses of conrep (which belongs to hp-scripting-tools package )
# mandatory : facter & conrep tools scripts available in path.

## var : 
conrep="/sbin/conrep"


if ! which facter ; then 
	echo "The tool < facter > seems not to be available. Please check" && exit 3
fi


res=$(facter productname |grep -Eo "Gen9")


# main test : to be processed only on g9 servers : 

if [[ "$res" != "Gen9" ]] ; then 
    echo "this server is not a Gen9" && exit 3
else 
##	# check mandatory tool presence 
	if ! type  "$conrep"  &>/dev/null; then
		echo "conrep is not available on this system"  && exit 1
	else 
		conrep -s -f - |grep -iq "Maximum performance"
		conrep_check="$?"
		if [ _"${conrep_check}" != _"0" ] ; then 
		    echo "< Maximum performance > bios setting is not configured on this server please check " && exit 2 
        else
            echo "ALLOK" && exit 0
        	fi 
	fi 
fi
