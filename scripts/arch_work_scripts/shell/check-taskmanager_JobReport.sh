#!/bin/bash
# vim: ts=4 sw=4 et
#
# check-taskmanager_JobReport.sh: Clement LEFORT <c.lefort@pixmania-group.com>
#			          jeudi 6 février 2014, 15:36:49 (UTC+0100)
#

BASEOID='.1.3.6.1.4.1.38673.1.28.5'
MODE=''

Nbr_HOST_Reporter=$(grep host_list /etc/taskmanager/taskmanager.conf 2>/dev/null | grep -o cron | wc -l)
Nbr_PIDS_Reporter=$(find /var/run/taskmanager/ -name "reporter.*.pid" 2>/dev/null | wc -l)


print_usage() {
    cat <<EOF
Usage: $(basename $0) [-h] {-g|-n|-s} OID [VALUE]

Options:
   -g  get value
   -h  display this help and exit
   -n  get next value
   -s  set value
EOF
}

snmp_get() {
    case "$1" in
        1)
            echo -e "$BASEOID.$1\nINTEGER"
            if [ $Nbr_PIDS_Reporter = 0 ]; then
                echo 2
            elif [ $Nbr_HOST_Reporter != $Nbr_PIDS_Reporter ]; then
                echo 1
            elif [ $Nbr_HOST_Reporter = $Nbr_PIDS_Reporter ]; then
                echo 0
            fi
            ;;
        2)
            echo -e "$BASEOID.$1\nSTRING"
            if [ $Nbr_PIDS_Reporter = 0 ]; then
                echo '0 proc JobReport running'
            elif [ $Nbr_HOST_Reporter != $Nbr_PIDS_Reporter ]; then
                echo "Only $Nbr_PIDS_Reporter/$Nbr_HOST_Reporter proc JobReport running" 
            elif [ $Nbr_HOST_Reporter = $Nbr_PIDS_Reporter ]; then
                echo "$Nbr_PIDS_Reporter proc JobReport running"
            fi
    ;;
    esac
}

# Parse for command-line arguments
while getopts 'ghns' options; do
    case "$options" in
        g) MODE='get' ;;
        n) MODE='next' ;;
        s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
        h) print_usage; exit 0 ;;
        *) print_usage; exit 1 ;;
    esac
done

shift $(($OPTIND-1))

if [ $# -ne 1 -o -z "$MODE" ]; then
    print_usage
    exit 1
fi

# Check for requested OID
OID=$1

if ! (echo $OID | grep -qE "^$BASEOID"); then
    echo "Error: base OID must begin with $BASEOID" >&2
    exit 1
fi

case ${OID#$BASEOID} in
    '')
        if [ "$MODE" == 'next' ]; then
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" == 'get' ]; then
            snmp_get 1
        else
            snmp_get 2
        fi
        ;;
    .2)
        if [ "$MODE" == 'get' ]; then
            snmp_get 2
        fi
        ;;
esac

