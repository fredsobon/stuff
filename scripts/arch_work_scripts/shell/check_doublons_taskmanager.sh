#!/bin/bash
#
#
BASEOID='.1.3.6.1.4.1.38673.1.35'
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

check_doublons_TSKManager() {

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

FLAG="/mnt/share/taskmanager/TransactionalFlag.txt"
STATE=`cat $FLAG | awk -F "##" '{print$1}'`

case $STATE in

CLOSED)

VAR=$(stat -c  %Y $FLAG)
NOW=$(date +"%s")
AGE=$((NOW - VAR))

if [ "$AGE" -lt "61" ]; then
    STATUS=$STATE_OK
    MESSAGE="OK -- $STATE -- $AGE"
else
    STATUS=$STATE_CRITICAL
    MESSAGE="KO : Pb de lancement du Cron php taskmananger sur le master fréquence > 1 minute  "
fi
    ;;
OPEN)

VAR=$(stat -c  %Y $FLAG)
NOW=$(date +"%s")
AGE=$((NOW - VAR))

if [ "$AGE" -lt "60" ]; then
    STATUS=$STATE_OK
    MESSAGE="OK -- $STATE -- $AGE"
else
    STATUS=$STATE_CRITICAL
    MESSAGE="KO : Pb ordonnanceur taskmanager - Le délais d'exécution dépasse 1 minute. Tous les crons php qui suivent seront bloqués. Intervention humain s'impose voir mode opératoire dans le wiki"
fi
;;
*)
;;
esac

return $STATUS
return $MESSAGE


}
snmp_get() {
    check_doublons_TSKManager
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


