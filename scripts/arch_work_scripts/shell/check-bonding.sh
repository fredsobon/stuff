#!/bin/sh

# vim: sw=4 ts=4
#
# Authors: David Larquey <d.larquey@pixmania-group.com>
# Date: Thu Dec  6 13:57:37 CET 2012


# This script 
usage() {
    cat <<EOS
$(basename $0) - Check network devices of a bonding

Check if all network devices of a bonding are UP

SYNTAX

$(basename $0) [-h] [{-g|-n|-s} OID [VALUE]]

     -h    This help
     -g    get SNMP value
     -n    get next SNMP value
     -s    set SNMP value

EOS
}



###### SNMP functions ######
snmp_get() {
    case "$1" in
        0)
            echo "$BASEOID.$1"
            echo 'INTEGER'
            echo "$CHECK_STATUS"
            ;;
        1)
            echo "$BASEOID.$1"
            echo 'STRING'
            echo "$CHECK_MSG"
            ;;
    esac
}
######


###### Check functions ######
# The return of the main check function 'docheck' must fill $CHECK_STATUS and $CHECK_MSG

init_return() {
        CHECK_STATUS=0
        CHECK_MSG=
}

# Return check functions
set_return() {
    CHECK_STATUS=$1
    CHECK_MSG="$2"
    [ -z "$MODE" ] && echo "$CHECK_STATUS - $CHECK_MSG"
}

check_nr_path() {
    local paths=$1
    [ "${paths}" -lt "${nr_sessions}" ] && return 0
    return 1
}

aggr_return() {
    local tmp_check_status=$1
    local tmp_check_msg="$2"
    if [ ${tmp_check_status} -ge $check_status ]; then
        [ -n "$check_msg" ] && check_msg="${tmp_check_msg} - ${check_msg}" || check_msg="${tmp_check_msg}"
        check_status=${tmp_check_status}
    else
        [ -n "$check_msg" ] && check_msg="${check_msg} - ${tmp_check_msg}" || check_msg="${tmp_check_msg}"
    fi
}


# Main check function
docheck() {
    local check_status=0
    local check_msg=

    [ -d /proc/net/bonding ] || { set_return 0 "OK" && return; }

    for bond in $(ls -1 /proc/net/bonding/); do
        msg="${bond}:"
        msg_temp=
        eths=($(cat /proc/net/bonding/${bond}|grep "Slave Interface: "|awk -F: '{print $2}'|awk '{print $1}'|xargs))

        # check the number of active devices in the bonding
        if [ ${#eths[@]} -lt 2 ]; then
            if [ ${#eths[@]} -eq 0 ]; then
                aggr_return 1 "ERROR: No active network devices (${#eths[@]}) Should be greater or equal than 2"
            else
                aggr_return 1 "WARNING: Not enough active network devices (${#eths[@]}) Should be greater or equal than 2"
            fi
        fi

        for eth in ${eths[@]}; do
            msg_temp="${msg_temp} $(cat /proc/net/bonding/${bond}|grep "Slave Interface: $eth" -A 3|awk -F: '{print $2}'|awk '{print $1}'|xargs),"
        done
        msg="${msg}${msg_temp}"
        cnt=$(echo $msg_temp |grep -c ' down ')

        if [ $cnt -ge ${#eths[@]} ]; then
            aggr_return 2 "ERROR: ${msg}"
        elif [ $cnt -ge 1 ]; then
            aggr_return 1 "WARNING: ${msg}"
        else
            aggr_return 0 "OK: ${msg}"
        fi
    done

    [ -z "$check_msg" ] && check_msg='OK'
    set_return ${check_status} "${check_msg}"
}


######



########
# MAIN #
########

MODE=

BASEOID='.1.3.6.1.4.1.38673.1.17'
while getopts 'gnshf' option; do
    case "$option" in
        # snmp
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;

        # others
        h) { usage; exit 0; } ;;
        f) ARG_PRINT_ONLY_FAILED_PATH=1 ;;
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
