#!/bin/bash

# vim: sw=4 ts=4
#

BASEOID='.1.3.6.1.4.1.38673.1.36'
oratab='/etc/oratab'
err_cnt="0"
err_msg=""
status_msg=""

usage() {
    cat <<EOS
$(basename $0) - Check oracle cluster vote disks state

Check if the oracle cluster vote disks are available

SYNTAX

$(basename $0) [-h] [{-g|-n|-s} OID [VALUE]]

     -h    This help
     -g    get SNMP value
     -n    get next SNMP value
     -s    set SNMP value
	 -v	   expected value as result

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
set_return_code() {
    CHECK_STATUS=$1
    CHECK_MSG="$2"
    [ -z "$MODE" ] && echo -e "$CHECK_STATUS - $CHECK_MSG"
}


force_exit_code() {
    CHECK_STATUS=$1
    CHECK_MSG="$2"
    [ -z "$MODE" ] && echo -e "$CHECK_STATUS - $CHECK_MSG"
	exit $CHECK_STATUS
}

docheck() {
    local check_status=0
    local check_msg=

	[ -n "$EXPECTED_VOTEDISKS" ] || force_exit_code 3 "Missing expected value as argument"
	[ -n "$ORA_HOME" ] || force_exit_code 3 "Can't find the Grid Infra ORACLE HOME"
	BIN="${ORA_HOME}/bin/crsctl"
	[ -x "$BIN" ] || force_exit_code 3 "Can't find the binary: $BIN"
    cnt_votedisks=$($BIN query css votedisk|egrep -c "ONLINE")
    if [ $cnt_votedisks -ne $EXPECTED_VOTEDISKS ] ; then
        check_status="2"
        check_msg="Invalid expected number of vote disks: $cnt_votedisks/$EXPECTED_VOTEDISKS"
    else
        check_status="0"
        check_msg="OK"
    fi
    
    set_return_code $check_status "$check_msg"
}

#######
# MAIN #
########

MODE=


while getopts 'gnshv:' option; do
    case "$option" in
        # snmp
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        # others
		v) EXPECTED_VOTEDISKS=$OPTARG ;;
        h) { usage; exit 0; } ;;
    esac
done
shift $(($OPTIND-1))

# Check for requested OID
OID=$1
# Init the return var
init_return

ORA_HOME=$(cat $oratab|grep "^+ASM"|cut -d':' -f2)
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

