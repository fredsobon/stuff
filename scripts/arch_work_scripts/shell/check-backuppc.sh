#!/bin/bash
# vim: ts=4 sw=4 et
#

BASEOID='.1.3.6.1.4.1.38673.1.27'
MODE=''
TMPDIR=/tmp/$(basename $0 .sh)
CRITICAL_BACKUP_TIME=604800

# Functions

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

parse_backuppc_status() {
    result=0
    cur_time=$(date +%s)

    # Create temporary folder
    [ ! -d "$TMPDIR" ] && mkdir -p "$TMPDIR"

    # Check if status file is recent
    if [ -e $TMPDIR/status ]; then
      status_age=$(stat --printf %Y $TMPDIR/status)
      if [ $(( cur_time - status_age )) -le 60 ]; then
          return
      fi
    fi

    # Purge result message
    echo > $TMPDIR/result_msg

    # Backuppc command splitted line by line
    sudo -u backuppc /usr/share/backuppc/bin/BackupPC_serverMesg status hosts | awk 'BEGIN {FS="},"}; {for(i = 1; i<=NF; i++) print $i}' > $TMPDIR/status
    
    # Test result file content :
if [ ! -s $TMPDIR/status ] ; then
  echo " status file is EMPTY : PB with backuppc. "
else
    while read line ; do
        # If not a real host
        echo "$line" | grep -q 'userReq' || continue

        fqdn=$(echo "$line" | sed -rn 's/[^"]+?"([^"]+)".*/\1/p')

        # Check error message
        error=''
        if echo "$line" | grep -q 'error' ; then
            error=$(echo "$line" | sed -rn 's/.*"error" => "([^"]+)".*/\1/p')
        fi

        # Get backup age
        backup_time=$(echo "$line" | sed -rn 's/.*"lastGoodBackupTime" => "([0-9]+)".*/\1/p')

        # Process result
        if [ -n "$error" ] ; then
            echo "$fqdn ($error)" >> $TMPDIR/result_msg
            result=1
        elif [ $(( cur_time - backup_time )) -ge $CRITICAL_BACKUP_TIME ] ; then
            echo "$fqdn (last good backup is older than $CRITICAL_BACKUP_TIME seconds)" >> $TMPDIR/result_msg
            result=1
        fi

    done < $TMPDIR/status
fi
    echo $result > $TMPDIR/result_code
}

snmp_get() {
    parse_backuppc_status
    case "$1" in
        1)
            echo -e "$BASEOID.$1\nINTEGER"
            cat $TMPDIR/result_code
            ;;
        2)
            echo -e "$BASEOID.$1\nSTRING"
            cat $TMPDIR/result_msg | sed -e ':a;N;$!ba;s/\n/; /g'
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
