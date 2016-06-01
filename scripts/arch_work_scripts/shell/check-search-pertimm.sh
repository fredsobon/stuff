#!/bin/bash
#
#
BASEOID='.1.3.6.1.4.1.38673.1.30.4'
MODE=''
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

check_Search_pertimm() {
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
valeur=` grep -c CRITICAL /tmp/rapport_Search `
war=`grep -c WARNING /tmp/rapport_Search `

age_rapport_Search=$(expr `date +%s` - `stat -c %Z /tmp/rapport_Search`)

if [ "$age_rapport_Search" -gt "400" ] ; then 
    STATUS=$STATE_WARNING
    MESSAGE="Cron /usr/local/bin/check_search_by_projects.sh does not run" 
elif [ "$valeur" != "0" ]; then
        STATUS=$STATE_CRITICAL
        MESSAGE=`cat /tmp/rapport_Search|grep -Ev "OK|WARNING|started|=="`
elif [ "$war" != "0" ]; then
        STATUS=$STATE_WARNING
        MESSAGE=`cat /tmp/rapport_Search|grep -Ev "OK|WARNING|started|==" `
else
        STATUS=$STATE_OK
        MESSAGE="OK - ALL SEARCH ARE UP"
fi

return $STATUS
return $MESSAGE
}

snmp_get() {
    check_Search_pertimm
    case "$1" in
        0)
            echo -e "$BASEOID.$1\nINTEGER"
            echo $STATUS 
            ;;
        1)
            echo -e "$BASEOID.$1\nSTRING"
            echo $MESSAGE 
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
            snmp_get 0
       fi
        ;;
    .0)
        if [ "$MODE" == 'get' ]; then
            snmp_get 0
        else
            snmp_get 1
        fi
        ;;
    .1)
        if [ "$MODE" == 'get' ]; then
            snmp_get 1
        fi
        ;;
esac

