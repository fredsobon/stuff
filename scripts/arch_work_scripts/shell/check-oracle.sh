#!/bin/bash

# vim: sw=4 ts=4
#
# Authors: j.tetillon <j.tetillon@pixmania-group.com>
# Date: ven. juin 28 15:07:15 CEST 2013

BASEOID='.1.3.6.1.4.1.38673.1.24'

datafile="/etc/oratab"
err_cnt="0"
err_msg=""
status_msg=""

usage() {
    cat <<EOS
$(basename $0) - Check database state

Check if the oracle DB hosted on the server are up

SYNTAX

$(basename $0) [-h] [{-g|-n|-s} OID [VALUE]]

     -h    This help
     -g    get SNMP value
     -n    get next SNMP value
     -s    set SNMP value

EOS
}

snmp_get() {
    case "$1" in
		0)
	    	echo -e "$BASEOID.$1\nINTEGER\n$CHECK_STATUS"
	    ;;
        1)
            echo -e "$BASEOID.$1\nSTRING\n$CHECK_MSG"
        ;;
    esac
}


init_return() {
        CHECK_STATUS=0
        CHECK_MSG=
}

# Return check functions
set_return() {
    CHECK_STATUS=$1
    CHECK_MSG="$2"
    [ -z "$MODE" ] && echo -e "$CHECK_STATUS - $CHECK_MSG"
}


docheck() {

    	local check_status=0
    	local check_msg=

	for line in $(cat $datafile |egrep -v '^#|^oracle|^\*|^\+|^cfg_rman' |cut -d ':' -f1); do
		dbstate=$(ps faux |grep ora_pmon_$line |grep -v grep)
		if [ -n "$dbstate" ]; then
			continue
		else
            echo "$(date) - DEBUG: $line is down." >> /tmp/check_pmon.debug
			err_cnt=$[err_cnt+1]
			err_msg="$(echo $err_msg) $line is Down " 
		fi
	done
	
	if [ "$err_cnt" -gt "0" ] ; then
		check_status="2"
		check_msg="$err_msg"
	
	else
		check_status="0"
		check_msg="OK"
	fi
	
	set_return $check_status "$check_msg"
}

#######
# MAIN #
########

MODE=


while getopts 'gnshf' option; do
    case "$option" in
        # snmp
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;

        # others
        h) { usage; exit 0; } ;;
    esac
done
shift $(($OPTIND-1))

# Check for requested OID
OID=$1
# Init the return var
init_return

# Do the check
if [ -z "$MODE" ]; then
    docheck | column -t
    exit 0
else
    docheck
fi

if [ -n "$MODE" ] && ! (echo $OID | grep -qE "^$BASEOID"); then
    echo "Error: base OID must begin with $BASEOID" >&2
    exit 1
fi

case ${OID#$BASEOID} in
    '')
        if [ "$MODE" = 'next' ]; then
            snmp_get 0
        fi
        ;;
    .0)
        if [ "$MODE" = 'get' ]; then
            snmp_get 0
        else
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" = 'get' ]; then
            snmp_get 1
        fi
        ;;
esac

exit 0

