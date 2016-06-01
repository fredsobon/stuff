#!/bin/bash

# vim: sw=2 ts=2
#
# Authors: David Larquey <d.larquey@pixmania-group.com>
# Modified by : Jeremie Tetillon <j.tetillon@e-merchant.com>
# Date: mardi 19 février 2013, 15:56:11 (UTC+0100)


# This script 
usage() {
    cat <<EOS
$(basename $0) - Check network devices (State, Speed & MTU)

Check State, Speed & MTU for network devices

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


# Check functions ######
# The return of the main check function 'docheck' must fill $CHECK_STATUS and $CHECK_MSG
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

read_conf(){
  target_speed="1000"
  target_mtu="1500"
  if [ -f "${conf}" ]; then
    spec=$(grep "^$1:" "${conf}")
    if [ -n "${spec}" ]; then
      target_speed=$(echo "${spec}" |cut -d ':' -f2)
      target_mtu=$(echo "${spec}" |cut -d ':' -f3)
    fi
  fi
}

# Main check function
docheck() {
    local check_status=0
    local check_msg=
    local errcnt=0
    conf="/etc/snmp/check-iface.conf"
      
    # check speed & mtu
    for iface in $(ls -1 /sys/class/net/ |grep 'eth'); do 
        read_conf $iface
        state=$(cat /sys/class/net/${iface}/operstate)
        if [ "${state}" == "up" ]; then
            msg_temp=
            speed=$(cat /sys/class/net/${iface}/speed)
            mtu=$(cat /sys/class/net/${iface}/mtu)
            if [ "${speed}" -ne "${target_speed}" ]; then
               msg_temp="${msg_temp} ${iface}: Speed: ${speed} ($target_speed)"
               errcnt=$((++errcnt))
            fi
            if [ "${mtu}" -ne "${target_mtu}" ]; then
               errcnt=$((++errcnt))
               msg_temp="${msg_temp} ${iface}: MTU: ${mtu} ($target_mtu)"
            fi
            msg="${msg} ${msg_temp}"



        fi
    done

	if [ ${errcnt} -ge "1" ]; then
            aggr_return 1 "ERROR: ${msg}"
        else
            aggr_return 0 "OK"
        fi

    [ -z "${check_msg}" ] && check_msg='OK'
    set_return ${check_status} "${check_msg}"

}

########
# MAIN #
########

MODE=

BASEOID='.1.3.6.1.4.1.38673.1.18'


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

